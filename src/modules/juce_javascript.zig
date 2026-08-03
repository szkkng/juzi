const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_javascript",
    .deps = &.{@import("juce_core.zig").juce_module},
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
        .root = ctx.juce.path("modules/juce_javascript"),
        .files = &.{"juce_javascript.cpp"},
        .flags = ctx.juce_required_flags.cxx,
    });
    return module;
}
