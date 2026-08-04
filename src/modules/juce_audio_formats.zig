const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_audio_formats",
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

    const is_darwin = ctx.target.result.os.tag.isDarwin();
    module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_audio_formats"),
        .files = &.{ctx.builder.fmt("juce_audio_formats.{s}", .{if (is_darwin) "mm" else "cpp"})},
        .flags = ctx.juce_required_flags.cxx,
    });
    module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_audio_formats"),
        .files = &.{
            "juce_audio_formats_flac_1.c",
            "juce_audio_formats_flac_2.c",
        },
        .flags = ctx.juce_required_flags.c,
    });
    switch (ctx.target.result.os.tag) {
        .macos => {
            module.linkFramework("CoreAudio", .{});
            module.linkFramework("CoreMIDI", .{});
            module.linkFramework("QuartzCore", .{});
            module.linkFramework("AudioToolbox", .{});
        },
        .ios => {
            module.linkFramework("AudioToolbox", .{});
            module.linkFramework("QuartzCore", .{});
        },
        else => {},
    }

    return module;
}
