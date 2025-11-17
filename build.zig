const std = @import("std");
pub const utils = @import("build_utils.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    inline for (.{
        @import("modules/juce_core.zig"),
        @import("modules/juce_events.zig"),
        @import("modules/juce_data_structures.zig"),
        @import("modules/juce_graphics.zig"),
        @import("modules/juce_gui_basics.zig"),
        @import("modules/juce_gui_extra.zig"),
        @import("modules/juce_audio_basics.zig"),
        @import("modules/juce_audio_devices.zig"),
        @import("modules/juce_audio_formats.zig"),
        @import("modules/juce_audio_processors.zig"),
        @import("modules/juce_audio_utils.zig"),
        @import("modules/juce_build_tools.zig"),
    }) |juce_module| {
        _ = juce_module.addModule(b, target, optimize);
    }
}
