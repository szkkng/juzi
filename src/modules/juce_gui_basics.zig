pub const juce_module = JuceModule.init("juce_gui_basics", createModule);

const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;
const JuceModule = @import("../JuceModule.zig");
const juce_data_structures = @import("juce_data_structures.zig").juce_module;
const juce_graphics = @import("juce_graphics.zig").juce_module;

fn createModule(ctx: JuceModule.BuildContext) *std.Build.Module {
    if (ctx.visited.contains(juce_module.name)) {
        return ctx.visited.get(juce_module.name).?;
    }

    const module = ctx.builder.createModule(.{
        .target = ctx.target,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_graphics.name,
                .module = juce_graphics.createModule(ctx),
            },
            .{
                .name = juce_data_structures.name,
                .module = juce_data_structures.createModule(ctx),
            },
        },
    });
    module.addIncludePath(ctx.upstream.path("modules"));

    const is_darwin = ctx.target.result.os.tag.isDarwin();
    module.addCSourceFiles(.{
        .root = ctx.upstream.path("modules/juce_gui_basics"),
        .files = &.{ctx.builder.fmt("juce_gui_basics.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });
    if (is_darwin) {
        darwin_sdk.addPaths(ctx.builder, module);
    }

    switch (ctx.target.result.os.tag) {
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

    ctx.visited.put(ctx.builder.allocator, juce_module.name, module) catch @panic("OOM");

    return module;
}
