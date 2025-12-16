pub const juce_module = JuceModule.init("juce_audio_utils", createModule);

const std = @import("std");
const darwin_sdk = @import("../darwin.zig").sdk;
const JuceModule = @import("../JuceModule.zig");
const juce_audio_processors = @import("juce_audio_processors.zig").juce_module;
const juce_audio_formats = @import("juce_audio_formats.zig").juce_module;
const juce_audio_devices = @import("juce_audio_devices.zig").juce_module;

fn createModule(ctx: JuceModule.BuildContext) *std.Build.Module {
    if (ctx.visited.contains(juce_module.name)) {
        return ctx.visited.get(juce_module.name).?;
    }

    const module = ctx.builder.createModule(.{
        .target = ctx.target,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_audio_processors.name,
                .module = juce_audio_processors.createModule(ctx),
            },
            .{
                .name = juce_audio_formats.name,
                .module = juce_audio_formats.createModule(ctx),
            },
            .{
                .name = juce_audio_devices.name,
                .module = juce_audio_devices.createModule(ctx),
            },
        },
    });
    module.addIncludePath(ctx.upstream.path("modules"));

    const is_darwin = ctx.target.result.os.tag.isDarwin();
    module.addCSourceFiles(.{
        .root = ctx.upstream.path("modules/juce_audio_utils"),
        .files = &.{ctx.builder.fmt("juce_audio_utils.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });
    if (is_darwin) {
        darwin_sdk.addPaths(ctx.builder, module);
    }

    switch (ctx.target.result.os.tag) {
        .macos => {
            module.linkFramework("CoreAudioKit", .{});
            module.linkFramework("DiscRecording", .{});
        },
        .ios => {
            module.linkFramework("CoreAudioKit", .{});
        },
        else => {},
    }

    ctx.visited.put(ctx.builder.allocator, juce_module.name, module) catch @panic("OOM");

    return module;
}
