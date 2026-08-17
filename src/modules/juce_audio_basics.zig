const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_audio_basics",
    .deps = &.{@import("juce_core.zig").juce_module},
    .configure = configure,
};

fn configure(root_module: *std.Build.Module, ctx: JuceModule.BuildContext) void {
    var flags: std.ArrayList([]const u8) = .empty;
    flags.appendSlice(ctx.builder.allocator, ctx.juce_required_flags.cxx) catch @panic("OOM");
    flags.append(ctx.builder.allocator, "-fno-sanitize=enum") catch @panic("OOM");

    const is_darwin = ctx.target.result.os.tag.isDarwin();
    root_module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_audio_basics"),
        .files = &.{ctx.builder.fmt("juce_audio_basics.{s}", .{if (is_darwin) "mm" else "cpp"})},
        .flags = flags.items,
    });

    if (is_darwin) {
        root_module.linkFramework("Accelerate", .{});
    }
}
