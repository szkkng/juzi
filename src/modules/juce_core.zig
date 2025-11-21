const std = @import("std");
const apple_sdk = @import("../apple_sdk.zig");

pub const name = "juce_core";

pub fn addModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    if (b.modules.contains(name)) {
        return b.modules.get(name).?;
    }

    const upstream = b.dependency("upstream", .{});
    const juce_core = b.addModule(name, .{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });
    juce_core.addIncludePath(upstream.path("modules"));
    juce_core.addIncludePath(upstream.path("modules/juce_core"));
    juce_core.addIncludePath(upstream.path("modules/juce_core/text"));
    juce_core.addIncludePath(upstream.path("modules/juce_core/serialisation"));

    juce_core.addCSourceFiles(.{
        .root = upstream.path("modules/juce_core"),
        .files = &.{"juce_core.mm"},
    });
    juce_core.addCSourceFiles(.{
        .root = upstream.path("modules"),
        .files = &.{
            "juce_core/juce_core_CompilationTime.cpp",
        },
    });

    if (target.result.os.tag.isDarwin()) {
        apple_sdk.addPaths(b, juce_core);
    }

    switch (target.result.os.tag) {
        .macos => {
            juce_core.linkFramework("Cocoa", .{});
            juce_core.linkFramework("Foundation", .{});
            juce_core.linkFramework("IOKit", .{});
            juce_core.linkFramework("Security", .{});
        },
        .ios => {
            juce_core.linkFramework("Foundation", .{});
        },
        else => {},
    }

    return juce_core;
}
