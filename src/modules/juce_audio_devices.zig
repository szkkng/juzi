const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;
const juce_audio_basics = @import("juce_audio_basics.zig");
const juce_events = @import("juce_events.zig");

pub const name = "juce_audio_devices";

pub fn addModule(
    b: *std.Build,
    upstream: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    if (b.modules.contains(name)) {
        return b.modules.get(name).?;
    }

    const juce_audio_devices = b.addModule(name, .{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_audio_basics.name,
                .module = juce_audio_basics.addModule(b, upstream, target, optimize),
            },
            .{
                .name = juce_events.name,
                .module = juce_events.addModule(b, upstream, target, optimize),
            },
        },
    });
    juce_audio_devices.addIncludePath(upstream.path("modules"));
    juce_audio_devices.addIncludePath(upstream.path("modules/juce_audio_devices"));

    const is_darwin = target.result.os.tag.isDarwin();
    juce_audio_devices.addCSourceFiles(.{
        .root = upstream.path("modules/juce_audio_devices"),
        .files = &.{b.fmt("juce_audio_devices.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });
    if (is_darwin) {
        darwin_sdk.addPaths(b, juce_audio_devices);
    }

    switch (target.result.os.tag) {
        .macos => {
            juce_audio_devices.linkFramework("CoreAudio", .{});
            juce_audio_devices.linkFramework("CoreMIDI", .{});
            juce_audio_devices.linkFramework("AudioToolbox", .{});
        },
        .ios => {
            juce_audio_devices.linkFramework("CoreAudio", .{});
            juce_audio_devices.linkFramework("CoreMIDI", .{});
            juce_audio_devices.linkFramework("AudioToolbox", .{});
            juce_audio_devices.linkFramework("AVFoundation", .{});
        },
        else => {},
    }

    return juce_audio_devices;
}
