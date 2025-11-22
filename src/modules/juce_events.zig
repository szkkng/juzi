const std = @import("std");
const apple_sdk = @import("../apple_sdk.zig");
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
    juce_events.addCSourceFiles(.{
        .root = upstream.path("modules/juce_events"),
        .files = &.{"juce_events.mm"},
    });

    if (target.result.os.tag.isDarwin()) {
        apple_sdk.addPaths(b, juce_events);
    }

    return juce_events;
}
