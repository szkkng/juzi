const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;
const juce_audio_basics = @import("juce_audio_basics.zig");
const juce_gui_extra = @import("juce_gui_extra.zig");

pub const name = "juce_audio_processors";

pub fn addModule(
    b: *std.Build,
    upstream: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    if (b.modules.contains(name)) {
        return b.modules.get(name).?;
    }

    const juce_audio_processors = b.addModule(name, .{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_audio_basics.name,
                .module = juce_audio_basics.addModule(b, upstream, target, optimize),
            },
            .{
                .name = juce_gui_extra.name,
                .module = juce_gui_extra.addModule(b, upstream, target, optimize),
            },
        },
    });
    juce_audio_processors.addIncludePath(upstream.path("modules"));
    juce_audio_processors.addIncludePath(upstream.path("modules/juce_audio_processors"));
    juce_audio_processors.addIncludePath(upstream.path("modules/juce_audio_processors/processors"));
    juce_audio_processors.addCSourceFiles(.{
        .root = upstream.path("modules/juce_audio_processors"),
        .files = &.{"juce_audio_processors.mm"},
    });

    if (target.result.os.tag.isDarwin()) {
        darwin_sdk.addPaths(b, juce_audio_processors);
    }

    switch (target.result.os.tag) {
        .macos => {
            juce_audio_processors.linkFramework("CoreAudio", .{});
            juce_audio_processors.linkFramework("CoreMIDI", .{});
            juce_audio_processors.linkFramework("AudioToolbox", .{});
        },
        .ios => {
            juce_audio_processors.linkFramework("AudioToolbox", .{});
        },
        else => {},
    }

    return juce_audio_processors;
}
