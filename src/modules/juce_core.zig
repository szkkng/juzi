const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_core",
    .deps = &.{},
    .create = create,
};

fn create(
    ctx: JuceModule.BuildContext,
) *std.Build.Module {
    const module = ctx.builder.createModule(.{
        .target = ctx.target,
        .optimize = ctx.optimize,
        .link_libcpp = true,
    });
    module.addIncludePath(ctx.juce.path("modules"));
    module.addCSourceFiles(.{
        .root = ctx.juce.path("modules"),
        .files = &.{
            "juce_core/juce_core_CompilationTime.cpp",
        },
        .flags = ctx.juce_required_flags.cxx,
    });

    const is_darwin = ctx.target.result.os.tag.isDarwin();
    module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_core"),
        .files = &.{ctx.builder.fmt("juce_core.{s}", .{if (is_darwin) "mm" else "cpp"})},
        .flags = ctx.juce_required_flags.cxx,
    });
    module.addCSourceFile(.{
        .file = ctx.juce.path("modules/juce_core/juce_core_zlib.c"),
        .flags = ctx.juce_required_flags.c,
    });
    switch (ctx.target.result.os.tag) {
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
