const std = @import("std");
const juce_audio_basics = @import("juce_audio_basics.zig");

pub const name = "juce_audio_formats";

pub fn addModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    if (b.modules.contains(name)) {
        return b.modules.get(name).?;
    }

    const upstream = b.dependency("upstream", .{});
    const juce_audio_formats = b.addModule(name, .{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_audio_basics.name,
                .module = juce_audio_basics.addModule(b, target, optimize),
            },
        },
    });
    juce_audio_formats.addIncludePath(upstream.path("modules"));
    juce_audio_formats.addIncludePath(upstream.path("modules/juce_audio_formats"));
    juce_audio_formats.addCSourceFiles(.{
        .root = upstream.path("modules/juce_audio_formats"),
        .files = &.{"juce_audio_formats.mm"},
    });
    switch (target.result.os.tag) {
        .macos => {
            juce_audio_formats.linkFramework("CoreAudio", .{});
            juce_audio_formats.linkFramework("CoreMIDI", .{});
            juce_audio_formats.linkFramework("QuartzCore", .{});
            juce_audio_formats.linkFramework("AudioToolbox", .{});
        },
        .ios => {
            juce_audio_formats.linkFramework("AudioToolbox", .{});
            juce_audio_formats.linkFramework("QuartzCore", .{});
        },
        else => {},
    }

    return juce_audio_formats;
}
