const std = @import("std");
const juce_cryptography = @import("juce_cryptography.zig");

pub const name = "juce_product_unlocking";

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
                .name = juce_cryptography.name,
                .module = juce_cryptography.addModule(b, upstream, target, optimize),
            },
        },
    });
    module.addIncludePath(upstream.path("modules"));

    const is_darwin = target.result.os.tag.isDarwin();
    module.addCSourceFiles(.{
        .root = upstream.path("modules/juce_product_unlocking"),
        .files = &.{b.fmt("juce_product_unlocking.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });

    return module;
}
