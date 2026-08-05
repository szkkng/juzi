const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_animation",
    .deps = &.{@import("juce_gui_basics.zig").juce_module},
    .configure = configure,
};

fn configure(root_module: *std.Build.Module, ctx: JuceModule.BuildContext) void {
    root_module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_animation"),
        .files = &.{"juce_animation.cpp"},
        .flags = ctx.juce_required_flags.cxx,
    });
}
