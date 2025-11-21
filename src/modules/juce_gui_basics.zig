const std = @import("std");
const apple_sdk = @import("../apple_sdk.zig");
const juce_data_structures = @import("juce_data_structures.zig");
const juce_graphics = @import("juce_graphics.zig");

pub const name = "juce_gui_basics";

pub fn addModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    if (b.modules.contains(name)) {
        return b.modules.get(name).?;
    }

    const upstream = b.dependency("upstream", .{});
    const juce_gui_basics = b.addModule(name, .{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_graphics.name,
                .module = juce_graphics.addModule(b, target, optimize),
            },
            .{
                .name = juce_data_structures.name,
                .module = juce_data_structures.addModule(b, target, optimize),
            },
        },
    });

    if (target.result.os.tag.isDarwin()) {
        apple_sdk.addPaths(b, juce_gui_basics);
    }

    juce_gui_basics.addIncludePath(upstream.path("modules"));
    juce_gui_basics.addIncludePath(upstream.path("modules/juce_gui_basics"));
    juce_gui_basics.addIncludePath(upstream.path("modules/juce_gui_basics/detail"));
    juce_gui_basics.addIncludePath(upstream.path("modules/juce_gui_basics/detail/native"));
    juce_gui_basics.addCSourceFiles(.{
        .root = upstream.path("modules/juce_gui_basics"),
        .files = &.{"juce_gui_basics.mm"},
    });
    switch (target.result.os.tag) {
        .macos => {
            juce_gui_basics.linkFramework("Cocoa", .{});
            juce_gui_basics.linkFramework("QuartzCore", .{});
            juce_gui_basics.linkFramework("Metal", .{ .weak = true });
            juce_gui_basics.linkFramework("MetalKit", .{ .weak = true });
        },
        .ios => {
            juce_gui_basics.linkFramework("CoreServices", .{});
            juce_gui_basics.linkFramework("UIKit", .{});
            juce_gui_basics.linkFramework("Metal", .{ .weak = true });
            juce_gui_basics.linkFramework("MetalKit", .{ .weak = true });
            juce_gui_basics.linkFramework("UniformTypeIdentifiers", .{ .weak = true });
            juce_gui_basics.linkFramework("UserNotifications", .{ .weak = true });
        },
        else => {},
    }

    return juce_gui_basics;
}
