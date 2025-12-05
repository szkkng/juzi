const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;
const juce_audio_basics = @import("juce_audio_basics.zig");

pub const name = "juce_opengl";

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
                .name = juce_audio_basics.name,
                .module = juce_audio_basics.addModule(b, upstream, target, optimize),
            },
        },
    });
    module.addIncludePath(upstream.path("modules"));

    const is_darwin = target.result.os.tag.isDarwin();
    module.addCSourceFiles(.{
        .root = upstream.path("modules/juce_opengl"),
        .files = &.{b.fmt("juce_opengl.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });

    if (is_darwin) {
        darwin_sdk.addPaths(b, module);
    }

    switch (target.result.os.tag) {
        .macos => {
            module.linkFramework("OpenGL", .{});
        },
        .ios => {
            module.linkFramework("OpenGLES", .{});
        },
        .linux => {
            module.linkSystemLibrary("gl", .{});
        },
        else => {},
    }

    return module;
}
