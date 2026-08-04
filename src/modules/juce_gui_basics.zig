const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_gui_basics",
    .deps = &.{
        @import("juce_graphics.zig").juce_module,
        @import("juce_data_structures.zig").juce_module,
    },
    .create = create,
};

fn create(ctx: JuceModule.BuildContext) *std.Build.Module {
    const module = ctx.builder.createModule(.{
        .target = ctx.target,
        .optimize = ctx.optimize,
        .link_libcpp = true,
    });
    module.addIncludePath(ctx.juce.path("modules"));

    const is_darwin = ctx.target.result.os.tag.isDarwin();
    module.addCSourceFiles(.{
        .root = ctx.juce.path("modules/juce_gui_basics"),
        .files = &.{
            ctx.builder.fmt("juce_gui_basics.{s}", .{if (is_darwin) "mm" else "cpp"}),
            "juce_gui_basics_2.cpp",
            "juce_gui_basics_3.cpp",
            "juce_gui_basics_4.cpp",
            "juce_gui_basics_5.cpp",
        },
        .flags = ctx.juce_required_flags.cxx,
    });

    switch (ctx.target.result.os.tag) {
        .macos => {
            module.linkFramework("Cocoa", .{});
            module.linkFramework("QuartzCore", .{});
            module.linkFramework("Metal", .{ .weak = true });
            module.linkFramework("MetalKit", .{ .weak = true });
        },
        .ios => {
            module.linkFramework("CoreServices", .{});
            module.linkFramework("UIKit", .{});
            module.linkFramework("Metal", .{ .weak = true });
            module.linkFramework("MetalKit", .{ .weak = true });
            module.linkFramework("UniformTypeIdentifiers", .{ .weak = true });
            module.linkFramework("UserNotifications", .{ .weak = true });
        },
        else => {},
    }

    return module;
}
