const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;
const juce_gui_basics = @import("juce_gui_basics.zig");

pub const name = "juce_gui_extra";

pub fn addModule(
    b: *std.Build,
    upstream: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    if (b.modules.contains(name)) {
        return b.modules.get(name).?;
    }

    const juce_gui_extra = b.addModule(name, .{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_gui_basics.name,
                .module = juce_gui_basics.addModule(b, upstream, target, optimize),
            },
        },
    });
    juce_gui_extra.addIncludePath(upstream.path("modules"));
    juce_gui_extra.addIncludePath(upstream.path("modules/juce_gui_extra"));

    const is_darwin = target.result.os.tag.isDarwin();
    juce_gui_extra.addCSourceFiles(.{
        .root = upstream.path("modules/juce_gui_extra"),
        .files = &.{b.fmt("juce_gui_extra.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });
    if (is_darwin) {
        darwin_sdk.addPaths(b, juce_gui_extra);
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
