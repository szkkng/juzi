const std = @import("std");
const apple_sdk = @import("../apple_sdk.zig");
const juce_audio_processors = @import("juce_audio_processors.zig");
const juce_audio_formats = @import("juce_audio_formats.zig");
const juce_audio_devices = @import("juce_audio_devices.zig");

pub const name = "juce_audio_utils";

pub fn addModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    if (b.modules.contains(name)) {
        return b.modules.get(name).?;
    }

    const upstream = b.dependency("upstream", .{});
    const juce_audio_utils = b.addModule(name, .{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_audio_processors.name,
                .module = juce_audio_processors.addModule(b, target, optimize),
            },
            .{
                .name = juce_audio_formats.name,
                .module = juce_audio_formats.addModule(b, target, optimize),
            },
            .{
                .name = juce_audio_devices.name,
                .module = juce_audio_devices.addModule(b, target, optimize),
            },
        },
    });
    juce_audio_utils.addIncludePath(upstream.path("modules"));
    juce_audio_utils.addIncludePath(upstream.path("modules/juce_audio_utils"));
    juce_audio_utils.addCSourceFiles(.{
        .root = upstream.path("modules/juce_audio_utils"),
        .files = &.{"juce_audio_utils.mm"},
    });

    if (target.result.os.tag.isDarwin()) {
        apple_sdk.addPaths(b, juce_audio_utils);
    }

    switch (target.result.os.tag) {
        .macos => {
            juce_audio_utils.linkFramework("CoreAudioKit", .{});
            juce_audio_utils.linkFramework("DiscRecording", .{});
        },
        .ios => {
            juce_audio_utils.linkFramework("CoreAudioKit", .{});
        },
        else => {},
    }

    return juce_audio_utils;
}
