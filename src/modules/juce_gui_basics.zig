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

    const module = b.addModule(name, .{
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
    module.addIncludePath(upstream.path("modules"));

    const is_darwin = target.result.os.tag.isDarwin();
    module.addCSourceFiles(.{
        .root = upstream.path("modules/juce_gui_basics"),
        .files = &.{b.fmt("juce_gui_basics.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });
    if (is_darwin) {
        darwin_sdk.addPaths(b, module);
    }

    switch (target.result.os.tag) {
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
