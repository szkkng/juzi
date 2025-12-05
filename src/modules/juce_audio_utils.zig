const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;
const juce_audio_processors = @import("juce_audio_processors.zig");
const juce_audio_formats = @import("juce_audio_formats.zig");
const juce_audio_devices = @import("juce_audio_devices.zig");

pub const name = "juce_audio_utils";

pub fn addModule(
    b: *std.Build,
    upstream: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    if (b.modules.contains(name)) {
        return b.modules.get(name).?;
    }

    const module = b.addModule(name, .{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_audio_processors.name,
                .module = juce_audio_processors.addModule(b, upstream, target, optimize),
            },
            .{
                .name = juce_audio_formats.name,
                .module = juce_audio_formats.addModule(b, upstream, target, optimize),
            },
            .{
                .name = juce_audio_devices.name,
                .module = juce_audio_devices.addModule(b, upstream, target, optimize),
            },
        },
    });
    module.addIncludePath(upstream.path("modules"));

    const is_darwin = target.result.os.tag.isDarwin();
    module.addCSourceFiles(.{
        .root = upstream.path("modules/juce_audio_utils"),
        .files = &.{b.fmt("juce_audio_utils.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });
    if (is_darwin) {
        darwin_sdk.addPaths(b, module);
    }

    switch (target.result.os.tag) {
        .macos => {
            module.linkFramework("CoreAudioKit", .{});
            module.linkFramework("DiscRecording", .{});
        },
        .ios => {
            module.linkFramework("CoreAudioKit", .{});
        },
        else => {},
    }

    return module;
}
