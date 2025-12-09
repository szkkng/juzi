pub const juce_module = JuceModule.init("juce_osc", createModule);

const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;
const JuceModule = @import("../JuceModule.zig");
const juce_events = @import("juce_events.zig").juce_module;

fn createModule(ctx: JuceModule.BuildContext) *std.Build.Module {
    if (ctx.visited.contains(juce_module.name)) {
        return ctx.visited.get(juce_module.name).?;
    }

    const module = ctx.builder.createModule(.{
        .target = ctx.target,
        .optimize = ctx.optimize,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_events.name,
                .module = juce_events.createModule(ctx),
            },
        },
    });
    module.addIncludePath(ctx.upstream.path("modules"));
    module.addCSourceFiles(.{
        .root = ctx.upstream.path("modules/juce_osc"),
        .files = &.{"juce_osc.cpp"},
    });
    if (ctx.target.result.os.tag.isDarwin()) {
        darwin_sdk.addPaths(ctx.builder, module);
    }

    ctx.visited.put(ctx.builder.allocator, juce_module.name, module) catch @panic("OOM");

    return module;
}
