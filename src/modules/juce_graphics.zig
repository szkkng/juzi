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

    const juce_graphics = b.addModule(name, .{
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
    juce_graphics.addIncludePath(upstream.path("modules"));
    juce_graphics.addIncludePath(upstream.path("modules/juce_graphics"));
    juce_graphics.addIncludePath(upstream.path("modules/juce_graphics/unicode"));
    juce_graphics.addIncludePath(upstream.path("modules/juce_graphics/fonts"));
    juce_graphics.addIncludePath(upstream.path("modules/juce_graphics/unicode/sheenbidi/Headers"));
    juce_graphics.addCSourceFiles(.{
        .root = upstream.path("modules/juce_graphics/unicode/sheenbidi/Source"),
        .files = &.{
            "BidiChain.c",
            "BidiTypeLookup.c",
            "BracketQueue.c",
            "GeneralCategoryLookup.c",
            "IsolatingRun.c",
            "LevelRun.c",
            "Object.c",
            "PairingLookup.c",
            "RunQueue.c",
            "SBAlgorithm.c",
            "SBBase.c",
            "SBCodepoint.c",
            "SBCodepointSequence.c",
            "SBLine.c",
            "SBLog.c",
            "SBMirrorLocator.c",
            "SBParagraph.c",
            "SBScriptLocator.c",
            "ScriptLookup.c",
            "ScriptStack.c",
            "SheenBidi.c",
            "StatusStack.c",
        },
    });
    juce_graphics.addCSourceFiles(.{
        .root = upstream.path("modules"),
        .files = &.{
            "juce_graphics/juce_graphics_Harfbuzz.cpp",
        },
    });

    const is_darwin = target.result.os.tag.isDarwin();
    juce_graphics.addCSourceFiles(.{
        .root = upstream.path("modules/juce_graphics"),
        .files = &.{b.fmt("juce_graphics.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });
    if (is_darwin) {
        darwin_sdk.addPaths(b, juce_graphics);
    }

    switch (target.result.os.tag) {
        .macos => {
            juce_graphics.linkFramework("Cocoa", .{});
            juce_graphics.linkFramework("QuartzCore", .{});
        },
        .ios => {
            juce_graphics.linkFramework("CoreGraphics", .{});
            juce_graphics.linkFramework("CoreImage", .{});
            juce_graphics.linkFramework("CoreText", .{});
            juce_graphics.linkFramework("QuartzCore", .{});
        },
        .linux => {
            juce_graphics.linkSystemLibrary("freetype2", .{});
            juce_graphics.linkSystemLibrary("fontconfig", .{});
        },
        else => {},
    }

    return juce_graphics;
}
