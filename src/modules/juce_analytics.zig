const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;
const juce_gui_basics = @import("juce_gui_basics.zig");

pub const name = "juce_analytics";

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
                .name = juce_gui_basics.name,
                .module = juce_gui_basics.addModule(b, upstream, target, optimize),
            },
        },
    });
    module.addIncludePath(upstream.path("modules"));
    module.addCSourceFiles(.{
        .root = upstream.path("modules/juce_analytics"),
        .files = &.{"juce_analytics.cpp"},
    });
    if (target.result.os.tag.isDarwin()) {
        darwin_sdk.addPaths(b, module);
    }

    return module;
}
