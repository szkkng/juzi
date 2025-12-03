const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;
const juce_core = @import("juce_core.zig");

pub const name = "juce_events";

pub fn addModule(
    b: *std.Build,
    upstream: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    if (b.modules.contains(name)) {
        return b.modules.get(name).?;
    }

    const juce_events = b.addModule(name, .{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_core.name,
                .module = juce_core.addModule(b, upstream, target, optimize),
            },
        },
    });
    juce_events.addIncludePath(upstream.path("modules"));
    juce_events.addIncludePath(upstream.path("modules/juce_events"));
    const is_darwin = target.result.os.tag.isDarwin();
    juce_events.addCSourceFiles(.{
        .root = upstream.path("modules/juce_events"),
        .files = &.{b.fmt("juce_events.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });
    if (is_darwin) {
        darwin_sdk.addPaths(b, juce_events);
    }

    return juce_events;
}
