const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_midi_ci",
    .deps = &.{@import("juce_audio_basics.zig").juce_module},
    .configure = configure,
};

fn configure(root_module: *std.Build.Module, ctx: JuceModule.BuildContext) void {
    root_module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_midi_ci"),
        .files = &.{"juce_midi_ci.cpp"},
        .flags = ctx.juce_required_flags.cxx,
    });
}
