const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;
const juce_data_structures = @import("juce_data_structures.zig");
const juce_graphics = @import("juce_graphics.zig");

pub const name = "juce_gui_basics";

pub fn addModule(
    b: *std.Build,
    upstream: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    if (b.modules.contains(name)) {
        return b.modules.get(name).?;
    }

    const juce_gui_basics = b.addModule(name, .{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_graphics.name,
                .module = juce_graphics.addModule(b, upstream, target, optimize),
            },
            .{
                .name = juce_data_structures.name,
                .module = juce_data_structures.addModule(b, upstream, target, optimize),
            },
        },
    });
    juce_gui_basics.addIncludePath(upstream.path("modules"));
    juce_gui_basics.addIncludePath(upstream.path("modules/juce_gui_basics"));
    juce_gui_basics.addIncludePath(upstream.path("modules/juce_gui_basics/detail"));
    juce_gui_basics.addIncludePath(upstream.path("modules/juce_gui_basics/detail/native"));

    const is_darwin = target.result.os.tag.isDarwin();
    juce_gui_basics.addCSourceFiles(.{
        .root = upstream.path("modules/juce_gui_basics"),
        .files = &.{b.fmt("juce_gui_basics.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });
    if (is_darwin) {
        darwin_sdk.addPaths(b, juce_gui_basics);
    }

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
