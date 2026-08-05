const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_build_tools",
    .deps = &.{@import("juce_gui_basics.zig").juce_module},
    .configure = configure,
};

fn configure(root_module: *std.Build.Module, ctx: JuceModule.BuildContext) void {
    root_module.addIncludePath(ctx.juce.path("extras/Build/juce_build_tools"));
    root_module.addCSourceFiles(.{
        .root = ctx.juce.path("extras/Build/juce_build_tools"),
        .files = &.{"juce_build_tools.cpp"},
        .flags = ctx.juce_required_flags.cxx,
    });
}
