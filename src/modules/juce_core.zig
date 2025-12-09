pub const juce_module = JuceModule.init("juce_core", createModule);

const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;
const JuceModule = @import("../JuceModule.zig");

fn createModule(
    ctx: JuceModule.BuildContext,
) *std.Build.Module {
    if (ctx.visited.contains(juce_module.name)) {
        return ctx.visited.get(juce_module.name).?;
    }

    const mod = ctx.builder.createModule(.{
        .target = ctx.target,
        .optimize = ctx.optimize,
        .link_libcpp = true,
    });
    mod.addIncludePath(ctx.upstream.path("modules"));
    mod.addCSourceFiles(.{
        .root = ctx.upstream.path("modules"),
        .files = &.{
            "juce_core/juce_core_CompilationTime.cpp",
        },
    });

    const is_darwin = ctx.target.result.os.tag.isDarwin();
    mod.addCSourceFiles(.{
        .root = ctx.upstream.path("modules/juce_core"),
        .files = &.{ctx.builder.fmt("juce_core.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });
    if (is_darwin) {
        darwin_sdk.addPaths(ctx.builder, mod);
    }

    switch (ctx.target.result.os.tag) {
        .macos => {
            mod.linkFramework("Cocoa", .{});
            mod.linkFramework("Foundation", .{});
            mod.linkFramework("IOKit", .{});
            mod.linkFramework("Security", .{});
        },
        .ios => {
            mod.linkFramework("Foundation", .{});
        },
        .linux => {
            mod.linkSystemLibrary("rt", .{});
            mod.linkSystemLibrary("dl", .{});
            mod.linkSystemLibrary("pthread", .{});
        },
        else => {},
    }

    ctx.visited.put(ctx.builder.allocator, juce_module.name, mod) catch @panic("OOM");

    return mod;
}
