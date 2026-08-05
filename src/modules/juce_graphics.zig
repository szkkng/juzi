const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_graphics",
    .deps = &.{@import("juce_events.zig").juce_module},
    .configure = configure,
};

fn configure(root_module: *std.Build.Module, ctx: JuceModule.BuildContext) void {
    root_module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_graphics"),
        .files = &.{"juce_graphics_Harfbuzz.cpp"},
        .flags = ctx.juce_required_flags.cxx,
    });
    root_module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_graphics"),
        .files = &.{
            "juce_graphics_Sheenbidi.c",
            "juce_graphics_libjpg_1.c",
            "juce_graphics_libjpg_2.c",
            "juce_graphics_libjpg_3.c",
            "juce_graphics_libpng.c",
            "juce_graphics_lunasvg.c",
        },
        .flags = ctx.juce_required_flags.c,
    });

    const is_darwin = ctx.target.result.os.tag.isDarwin();
    root_module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_graphics"),
        .files = &.{ctx.builder.fmt("juce_graphics.{s}", .{if (is_darwin) "mm" else "cpp"})},
        .flags = ctx.juce_required_flags.cxx,
    });
    switch (ctx.target.result.os.tag) {
        .macos => {
            root_module.linkFramework("Cocoa", .{});
            root_module.linkFramework("QuartzCore", .{});
        },
        .ios => {
            root_module.linkFramework("CoreGraphics", .{});
            root_module.linkFramework("CoreImage", .{});
            root_module.linkFramework("CoreText", .{});
            root_module.linkFramework("QuartzCore", .{});
        },
        .linux => {
            root_module.linkSystemLibrary("freetype2", .{});
            root_module.linkSystemLibrary("fontconfig", .{});
        },
        else => {},
    }
}
