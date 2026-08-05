const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_osc",
    .deps = &.{@import("juce_events.zig").juce_module},
    .configure = configure,
};

fn configure(root_module: *std.Build.Module, ctx: JuceModule.BuildContext) void {
    root_module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_osc"),
        .files = &.{"juce_osc.cpp"},
        .flags = ctx.juce_required_flags.cxx,
    });
}
