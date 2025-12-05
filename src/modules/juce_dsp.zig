const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;
const juce_audio_formats = @import("juce_audio_formats.zig");

pub const name = "juce_dsp";

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
                .name = juce_audio_formats.name,
                .module = juce_audio_formats.addModule(b, upstream, target, optimize),
            },
        },
    });
    module.addIncludePath(upstream.path("modules"));

    const is_darwin = target.result.os.tag.isDarwin();
    module.addCSourceFiles(.{
        .root = upstream.path("modules/juce_dsp"),
        .files = &.{b.fmt("juce_dsp.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });
    if (is_darwin) {
        darwin_sdk.addPaths(b, module);
    }

    switch (target.result.os.tag) {
        .macos => {
            module.linkFramework("Accelerate", .{});
        },
        .ios => {
            module.linkFramework("Accelerate", .{});
        },
        else => {},
    }

    return module;
}
