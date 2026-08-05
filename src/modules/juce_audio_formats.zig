const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_audio_formats",
    .deps = &.{@import("juce_audio_basics.zig").juce_module},
    .configure = configure,
};

fn configure(root_module: *std.Build.Module, ctx: JuceModule.BuildContext) void {
    const is_darwin = ctx.target.result.os.tag.isDarwin();
    root_module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_audio_formats"),
        .files = &.{ctx.builder.fmt("juce_audio_formats.{s}", .{if (is_darwin) "mm" else "cpp"})},
        .flags = ctx.juce_required_flags.cxx,
    });
    root_module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_audio_formats"),
        .files = &.{
            "juce_audio_formats_flac_1.c",
            "juce_audio_formats_flac_2.c",
        },
        .flags = ctx.juce_required_flags.c,
    });
    switch (ctx.target.result.os.tag) {
        .macos => {
            root_module.linkFramework("CoreAudio", .{});
            root_module.linkFramework("CoreMIDI", .{});
            root_module.linkFramework("QuartzCore", .{});
            root_module.linkFramework("AudioToolbox", .{});
        },
        .ios => {
            root_module.linkFramework("AudioToolbox", .{});
            root_module.linkFramework("QuartzCore", .{});
        },
        else => {},
    }
}
