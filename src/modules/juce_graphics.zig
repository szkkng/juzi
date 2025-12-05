const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;
const juce_events = @import("juce_events.zig");

pub const name = "juce_graphics";

pub fn addModule(
    b: *std.Build,
    upstream: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    if (b.modules.contains(name)) {
        return b.modules.get(name).?;
    }

    const module = b.addModule(name, .{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_events.name,
                .module = juce_events.addModule(b, upstream, target, optimize),
            },
        },
    });
    module.addIncludePath(upstream.path("modules"));
    module.addCSourceFiles(.{
        .root = upstream.path("modules/juce_graphics"),
        .files = &.{
            "juce_graphics_Harfbuzz.cpp",
            "juce_graphics_Sheenbidi.c",
        },
    });

    const is_darwin = target.result.os.tag.isDarwin();
    module.addCSourceFiles(.{
        .root = upstream.path("modules/juce_graphics"),
        .files = &.{b.fmt("juce_graphics.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });
    if (is_darwin) {
        darwin_sdk.addPaths(b, module);
    }

    switch (target.result.os.tag) {
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
