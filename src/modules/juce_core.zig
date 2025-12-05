const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;

pub const name = "juce_core";

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
        .link_libcpp = true,
    });
    module.addIncludePath(upstream.path("modules"));
    module.addCSourceFiles(.{
        .root = upstream.path("modules"),
        .files = &.{
            "juce_core/juce_core_CompilationTime.cpp",
        },
    });

    const is_darwin = target.result.os.tag.isDarwin();
    module.addCSourceFiles(.{
        .root = upstream.path("modules/juce_core"),
        .files = &.{b.fmt("juce_core.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });
    if (is_darwin) {
        darwin_sdk.addPaths(b, module);
    }

    switch (target.result.os.tag) {
        .macos => {
            module.linkFramework("Cocoa", .{});
            module.linkFramework("Foundation", .{});
            module.linkFramework("IOKit", .{});
            module.linkFramework("Security", .{});
        },
        .ios => {
            module.linkFramework("Foundation", .{});
        },
        .linux => {
            module.linkSystemLibrary("rt", .{});
            module.linkSystemLibrary("dl", .{});
            module.linkSystemLibrary("pthread", .{});
        },
        else => {},
    }

    return module;
}
