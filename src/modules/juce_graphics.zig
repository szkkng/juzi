pub const juce_module = JuceModule.init("juce_graphics", createModule);

const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;
const JuceModule = @import("../JuceModule.zig");
const juce_events = @import("juce_events.zig").juce_module;

fn createModule(ctx: JuceModule.BuildContext) *std.Build.Module {
    if (ctx.visited.contains(juce_module.name)) {
        return ctx.visited.get(juce_module.name).?;
    }

    const module = ctx.builder.createModule(.{
        .target = ctx.target,
        .optimize = ctx.optimize,
        .link_libc = true,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_events.name,
                .module = juce_events.createModule(ctx),
            },
        },
    });
    module.addIncludePath(ctx.upstream.path("modules"));
    module.addCSourceFiles(.{
        .root = ctx.upstream.path("modules/juce_graphics"),
        .files = &.{
            "juce_graphics_Harfbuzz.cpp",
            "juce_graphics_Sheenbidi.c",
        },
    });

    const is_darwin = ctx.target.result.os.tag.isDarwin();
    module.addCSourceFiles(.{
        .root = ctx.upstream.path("modules/juce_graphics"),
        .files = &.{ctx.builder.fmt("juce_graphics.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });
    if (is_darwin) {
        darwin_sdk.addPaths(ctx.builder, module);
    }

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

    ctx.visited.put(ctx.builder.allocator, juce_module.name, module) catch @panic("OOM");

    return module;
}
