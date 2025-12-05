const std = @import("std");
const juce_core = @import("juce_core.zig");

pub const name = "juce_javascript";

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
                .name = juce_core.name,
                .module = juce_core.addModule(b, upstream, target, optimize),
            },
        },
    });
    module.addIncludePath(upstream.path("modules"));
    module.addCSourceFiles(.{
        .root = upstream.path("modules/juce_javascript"),
        .files = &.{"juce_javascript.cpp"},
    });

    return module;
}
