const std = @import("std");
const juce_gui_basics = @import("juce_gui_basics.zig");

pub const name = "juce_build_tools";

pub fn addModule(
    b: *std.Build,
    upstream: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    if (b.modules.contains(name)) {
        return b.modules.get(name).?;
    }

    const juce_build_tools = b.addModule(name, .{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_gui_basics.name,
                .module = juce_gui_basics.addModule(b, upstream, target, optimize),
            },
        },
    });
    juce_build_tools.addIncludePath(upstream.path("modules"));
    juce_build_tools.addIncludePath(upstream.path("extras/Build/juce_build_tools"));
    juce_build_tools.addCSourceFiles(.{
        .root = upstream.path("extras/Build/juce_build_tools"),
        .files = &.{"juce_build_tools.cpp"},
    });

    return juce_build_tools;
}
