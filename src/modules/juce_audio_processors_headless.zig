const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;
const juce_audio_basics = @import("juce_audio_basics.zig");
const juce_events = @import("juce_events.zig");

pub const name = "juce_audio_processors_headless";

pub fn addModule(
    b: *std.Build,
    upstream: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    if (b.modules.contains(name)) {
        return b.modules.get(name).?;
    }

    const juce_audio_processors_headless = b.addModule(name, .{
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
    juce_audio_processors_headless.addIncludePath(upstream.path("modules"));
    juce_audio_processors_headless.addIncludePath(upstream.path("modules/juce_audio_processors_headless"));
    juce_audio_processors_headless.addIncludePath(upstream.path("modules/juce_audio_processors_headless/processors"));
    juce_audio_processors_headless.addIncludePath(upstream.path("modules/juce_audio_processors_headless/format_types"));

    const is_darwin = target.result.os.tag.isDarwin();
    juce_audio_processors_headless.addCSourceFiles(.{
        .root = upstream.path("modules/juce_audio_processors_headless"),
        .files = &.{b.fmt("juce_audio_processors_headless.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });
    if (is_darwin) {
        darwin_sdk.addPaths(b, juce_audio_processors_headless);
    }

    switch (target.result.os.tag) {
        .macos => {
            juce_audio_processors_headless.linkFramework("CoreAudio", .{});
            juce_audio_processors_headless.linkFramework("CoreMIDI", .{});
            juce_audio_processors_headless.linkFramework("AudioToolbox", .{});
        },
        .ios => {
            juce_audio_processors_headless.linkFramework("AudioToolbox", .{});
        },
        else => {},
    }

    return juce_audio_processors_headless;
}
