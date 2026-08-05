const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_core",
    .deps = &.{},
    .configure = configure,
};

fn configure(root_module: *std.Build.Module, ctx: JuceModule.BuildContext) void {
    root_module.addCSourceFiles(.{
        .root = ctx.juce.path("modules"),
        .files = &.{"juce_core/juce_core_CompilationTime.cpp"},
        .flags = ctx.juce_required_flags.cxx,
    });

    const is_darwin = ctx.target.result.os.tag.isDarwin();
    root_module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_core"),
        .files = &.{ctx.builder.fmt("juce_core.{s}", .{if (is_darwin) "mm" else "cpp"})},
        .flags = ctx.juce_required_flags.cxx,
    });
    root_module.addCSourceFile(.{
        .file = ctx.juce.path("modules/juce_core/juce_core_zlib.c"),
        .flags = ctx.juce_required_flags.c,
    });
    switch (ctx.target.result.os.tag) {
        .macos => {
            root_module.linkFramework("Cocoa", .{});
            root_module.linkFramework("Foundation", .{});
            root_module.linkFramework("IOKit", .{});
            root_module.linkFramework("Security", .{});
        },
        .ios => root_module.linkFramework("Foundation", .{}),
        .linux => {
            root_module.linkSystemLibrary("rt", .{});
            root_module.linkSystemLibrary("dl", .{});
            root_module.linkSystemLibrary("pthread", .{});
        },
        else => {},
    }
}
