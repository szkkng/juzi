const std = @import("std");
const juce_events = @import("juce_events.zig");

pub const name = "juce_data_structures";

pub fn addModule(
    b: *std.Build,
    upstream: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    if (b.modules.contains(name)) {
        return b.modules.get(name).?;
    }

    const juce_data_structures = b.addModule(name, .{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_events.name,
                .module = juce_events.addModule(b, upstream, target, optimize),
            },
        },
    });
    juce_data_structures.addIncludePath(upstream.path("modules"));
    juce_data_structures.addIncludePath(upstream.path("modules/juce_data_structures"));

    const is_darwin = target.result.os.tag.isDarwin();
    juce_data_structures.addCSourceFiles(.{
        .root = upstream.path("modules/juce_data_structures"),
        .files = &.{b.fmt("juce_data_structures.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });

    return juce_data_structures;
}
