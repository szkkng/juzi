pub const juce_module = JuceModule.init("juce_audio_processors", createModule);

const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;
const JuceModule = @import("../JuceModule.zig");
const juce_audio_processors_headless = @import("juce_audio_processors_headless.zig").juce_module;
const juce_gui_extra = @import("juce_gui_extra.zig").juce_module;

fn createModule(ctx: JuceModule.BuildContext) *std.Build.Module {
    if (ctx.visited.contains(juce_module.name)) {
        return ctx.visited.get(juce_module.name).?;
    }

    const module = ctx.builder.createModule(.{
        .target = ctx.target,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_audio_processors_headless.name,
                .module = juce_audio_processors_headless.createModule(ctx),
            },
            .{
                .name = juce_gui_extra.name,
                .module = juce_gui_extra.createModule(ctx),
            },
        },
    });
    module.addIncludePath(ctx.upstream.path("modules"));

    const is_darwin = ctx.target.result.os.tag.isDarwin();
    module.addCSourceFiles(.{
        .root = ctx.upstream.path("modules/juce_audio_processors"),
        .files = &.{ctx.builder.fmt("juce_audio_processors.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });
    if (is_darwin) {
        darwin_sdk.addPaths(ctx.builder, module);
    }

    ctx.visited.put(ctx.builder.allocator, juce_module.name, module) catch @panic("OOM");

    return module;
}
