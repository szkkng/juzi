const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_midi_ci",
    .deps = &.{@import("juce_audio_basics.zig").juce_module},
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
        .root = ctx.juce.path("modules/juce_midi_ci"),
        .files = &.{"juce_midi_ci.cpp"},
        .flags = ctx.juce_required_flags.cxx,
    });
    return module;
}
