const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_audio_basics",
    .deps = &.{@import("juce_core.zig").juce_module},
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
        .root = ctx.juce.path("modules/juce_audio_basics"),
        .files = &.{ctx.builder.fmt("juce_audio_basics.{s}", .{if (is_darwin) "mm" else "cpp"})},
        .flags = ctx.juce_required_flags.cxx,
    });
    switch (ctx.target.result.os.tag) {
        .macos => {
            module.linkFramework("Accelerate", .{});
        },
        .ios => {
            module.linkFramework("Accelerate", .{});
        },
        else => {},
    }

    return module;
}
