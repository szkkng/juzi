const std = @import("std");
const JuceModule = @import("../JuceModule.zig");

pub const juce_module: JuceModule = .{
    .name = "juce_gui_basics",
    .deps = &.{
        @import("juce_graphics.zig").juce_module,
        @import("juce_data_structures.zig").juce_module,
    },
    .configure = configure,
};

fn configure(root_module: *std.Build.Module, ctx: JuceModule.BuildContext) void {
    const is_darwin = ctx.target.result.os.tag.isDarwin();
    root_module.addCSourceFiles(.{
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
            root_module.linkFramework("Cocoa", .{});
            root_module.linkFramework("QuartzCore", .{});
            root_module.linkFramework("Metal", .{ .weak = true });
            root_module.linkFramework("MetalKit", .{ .weak = true });
        },
        .ios => {
            root_module.linkFramework("CoreServices", .{});
            root_module.linkFramework("UIKit", .{});
            root_module.linkFramework("Metal", .{ .weak = true });
            root_module.linkFramework("MetalKit", .{ .weak = true });
            root_module.linkFramework("UniformTypeIdentifiers", .{ .weak = true });
            root_module.linkFramework("UserNotifications", .{ .weak = true });
        },
        else => {},
    }
}
