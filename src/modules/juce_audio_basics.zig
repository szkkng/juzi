const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;
const juce_core = @import("juce_core.zig");

pub const name = "juce_audio_basics";

pub fn addModule(
    b: *std.Build,
    upstream: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    if (b.modules.contains(name)) {
        return b.modules.get(name).?;
    }

    const juce_audio_basics = b.addModule(name, .{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_core.name,
                .module = juce_core.addModule(b, upstream, target, optimize),
            },
        },
    });
    juce_audio_basics.addIncludePath(upstream.path("modules"));
    juce_audio_basics.addIncludePath(upstream.path("modules/juce_audio_basics"));
    juce_audio_basics.addIncludePath(upstream.path("modules/juce_audio_basics/buffers"));

    const is_darwin = target.result.os.tag.isDarwin();
    juce_audio_basics.addCSourceFiles(.{
        .root = upstream.path("modules/juce_audio_basics"),
        .files = &.{b.fmt("juce_audio_basics.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });
    if (is_darwin) {
        darwin_sdk.addPaths(b, juce_audio_basics);
    }

    switch (target.result.os.tag) {
        .macos => {
            juce_audio_basics.linkFramework("Accelerate", .{});
        },
        .ios => {
            juce_audio_basics.linkFramework("Accelerate", .{});
        },
        else => {},
    }

    return juce_audio_basics;
}
