const std = @import("std");
const apple_sdk = @import("../apple_sdk.zig");
const juce_gui_basics = @import("juce_gui_basics.zig");

pub const name = "juce_gui_extra";

pub fn addModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    if (b.modules.contains(name)) {
        return b.modules.get(name).?;
    }

    const upstream = b.dependency("upstream", .{});
    const juce_gui_extra = b.addModule(name, .{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_gui_basics.name,
                .module = juce_gui_basics.addModule(b, target, optimize),
            },
        },
    });
    juce_gui_extra.addIncludePath(upstream.path("modules"));
    juce_gui_extra.addIncludePath(upstream.path("modules/juce_gui_extra"));
    juce_gui_extra.addCSourceFiles(.{
        .root = upstream.path("modules/juce_gui_extra"),
        .files = &.{"juce_gui_extra.mm"},
    });

    if (target.result.os.tag.isDarwin()) {
        apple_sdk.addPaths(b, juce_gui_extra);
    }

    switch (target.result.os.tag) {
        .macos => {
            juce_gui_extra.linkFramework("WebKit", .{});
            juce_gui_extra.linkFramework("UserNotifications", .{ .weak = true });
        },
        .ios => {
            juce_gui_extra.linkFramework("WebKit", .{});
            juce_gui_extra.linkFramework("UserNotifications", .{ .weak = true });
        },
        else => {},
    }

    return juce_gui_extra;
}
