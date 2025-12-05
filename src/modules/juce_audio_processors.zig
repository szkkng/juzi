const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;
const juce_audio_processors_headless = @import("juce_audio_processors_headless.zig");
const juce_gui_extra = @import("juce_gui_extra.zig");

pub const name = "juce_audio_processors";

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
                .name = juce_audio_processors_headless.name,
                .module = juce_audio_processors_headless.addModule(b, upstream, target, optimize),
            },
            .{
                .name = juce_gui_extra.name,
                .module = juce_gui_extra.addModule(b, upstream, target, optimize),
            },
        },
    });
    module.addIncludePath(upstream.path("modules"));

    const is_darwin = target.result.os.tag.isDarwin();
    module.addCSourceFiles(.{
        .root = upstream.path("modules/juce_audio_processors"),
        .files = &.{b.fmt("juce_audio_processors.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });
    if (is_darwin) {
        darwin_sdk.addPaths(b, module);
    }

    return module;
}
