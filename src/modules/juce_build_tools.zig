const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_build_tools",
    .deps = &.{@import("juce_gui_basics.zig").juce_module},
    .create = create,
};

fn create(ctx: JuceModule.BuildContext) *std.Build.Module {
    const module = ctx.builder.createModule(.{
        .target = ctx.target,
        .optimize = ctx.optimize,
        .link_libcpp = true,
    });
    module.addIncludePath(ctx.juce.path("modules"));
    module.addIncludePath(ctx.juce.path("extras/Build/juce_build_tools"));
    module.addCSourceFiles(.{
        .root = ctx.juce.path("extras/Build/juce_build_tools"),
        .files = &.{"juce_build_tools.cpp"},
        .flags = ctx.juce_required_flags.cxx,
    });
    return module;
}
