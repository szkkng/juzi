const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_audio_utils",
    .deps = &.{
        @import("juce_audio_processors.zig").juce_module,
        @import("juce_audio_formats.zig").juce_module,
        @import("juce_audio_devices.zig").juce_module,
    },
    .configure = configure,
};

fn configure(root_module: *std.Build.Module, ctx: JuceModule.BuildContext) void {
    const is_darwin = ctx.target.result.os.tag.isDarwin();
    root_module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_audio_utils"),
        .files = &.{ctx.builder.fmt("juce_audio_utils.{s}", .{if (is_darwin) "mm" else "cpp"})},
        .flags = ctx.juce_required_flags.cxx,
    });
    switch (ctx.target.result.os.tag) {
        .macos => {
            root_module.linkFramework("CoreAudioKit", .{});
            root_module.linkFramework("DiscRecording", .{});
        },
        .ios => root_module.linkFramework("CoreAudioKit", .{}),
        else => {},
    }
}
