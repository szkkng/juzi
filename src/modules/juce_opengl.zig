const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_opengl",
    .deps = &.{@import("juce_gui_extra.zig").juce_module},
    .configure = configure,
};

fn configure(root_module: *std.Build.Module, ctx: JuceModule.BuildContext) void {
    const is_darwin = ctx.target.result.os.tag.isDarwin();
    root_module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_opengl"),
        .files = &.{ctx.builder.fmt("juce_opengl.{s}", .{if (is_darwin) "mm" else "cpp"})},
        .flags = ctx.juce_required_flags.cxx,
    });

    switch (ctx.target.result.os.tag) {
        .macos => root_module.linkFramework("OpenGL", .{}),
        .ios => root_module.linkFramework("OpenGLES", .{}),
        .linux => root_module.linkSystemLibrary("gl", .{}),
        else => {},
    }
}
