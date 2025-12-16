pub const juce_module = JuceModule.init("juce_midi_ci", createModule);

const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;
const JuceModule = @import("../JuceModule.zig");
const juce_audio_basics = @import("juce_audio_basics.zig").juce_module;

fn createModule(ctx: JuceModule.BuildContext) *std.Build.Module {
    if (ctx.visited.contains(juce_module.name)) {
        return ctx.visited.get(juce_module.name).?;
    }

    const module = ctx.builder.createModule(.{
        .target = ctx.target,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_audio_basics.name,
                .module = juce_audio_basics.createModule(ctx),
            },
        },
    });
    module.addIncludePath(ctx.upstream.path("modules"));
    module.addCSourceFiles(.{
        .root = ctx.upstream.path("modules/juce_midi_ci"),
        .files = &.{"juce_midi_ci.cpp"},
    });
    if (ctx.target.result.os.tag.isDarwin()) {
        darwin_sdk.addPaths(ctx.builder, module);
    }

    ctx.visited.put(ctx.builder.allocator, juce_module.name, module) catch @panic("OOM");

    return module;
}
