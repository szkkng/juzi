const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_graphics",
    .deps = &.{@import("juce_events.zig").juce_module},
    .create = create,
};

fn create(ctx: JuceModule.BuildContext) *std.Build.Module {
    const module = ctx.builder.createModule(.{
        .target = ctx.target,
        .optimize = ctx.optimize,
        .link_libcpp = true,
    });
    module.addIncludePath(ctx.juce.path("modules"));
    module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_graphics"),
        .files = &.{"juce_graphics_Harfbuzz.cpp"},
        .flags = ctx.juce_required_flags.cxx,
    });
    module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_graphics"),
        .files = &.{"juce_graphics_Sheenbidi.c"},
        .flags = ctx.juce_required_flags.c,
    });

    const is_darwin = ctx.target.result.os.tag.isDarwin();
    module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_graphics"),
        .files = &.{ctx.builder.fmt("juce_graphics.{s}", .{if (is_darwin) "mm" else "cpp"})},
        .flags = ctx.juce_required_flags.cxx,
    });
    switch (ctx.target.result.os.tag) {
        .macos => {
            module.linkFramework("Cocoa", .{});
            module.linkFramework("QuartzCore", .{});
        },
        .ios => {
            module.linkFramework("CoreGraphics", .{});
            module.linkFramework("CoreImage", .{});
            module.linkFramework("CoreText", .{});
            module.linkFramework("QuartzCore", .{});
        },
        .linux => {
            module.linkSystemLibrary("freetype2", .{});
            module.linkSystemLibrary("fontconfig", .{});
        },
        else => {},
    }

    return module;
}
