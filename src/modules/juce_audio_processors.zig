const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_audio_processors",
    .deps = &.{
        @import("juce_audio_processors_headless.zig").juce_module,
        @import("juce_gui_extra.zig").juce_module,
    },
    .configure = configure,
};

fn configure(root_module: *std.Build.Module, ctx: JuceModule.BuildContext) void {
    const is_darwin = ctx.target.result.os.tag.isDarwin();
    root_module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_audio_processors"),
        .files = &.{ctx.builder.fmt("juce_audio_processors.{s}", .{if (is_darwin) "mm" else "cpp"})},
        .flags = ctx.juce_required_flags.cxx,
    });
}
