const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_animation",
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
    module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_animation"),
        .files = &.{"juce_animation.cpp"},
        .flags = ctx.juce_required_flags.cxx,
    });
    return module;
}
