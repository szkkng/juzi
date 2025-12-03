const std = @import("std");

pub const JuceModule = enum {
    juce_core,
    juce_events,
    juce_data_structures,
    juce_graphics,
    juce_gui_basics,
    juce_gui_extra,
    juce_audio_basics,
    juce_audio_devices,
    juce_audio_formats,
    juce_audio_processors,
    juce_audio_processors_headless,
    juce_audio_utils,
    juce_build_tools,
};

pub const modules = [_]type{
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
    @import("modules/juce_audio_processors_headless.zig"),
    @import("modules/juce_audio_utils.zig"),
    @import("modules/juce_build_tools.zig"),
};
