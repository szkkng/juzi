pub const juce_module = JuceModule.init("juce_opengl", createModule);

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
        .optimize = ctx.optimize,
        .link_libcpp = true,
        .imports = &.{
            .{
                .name = juce_audio_basics.name,
                .module = juce_audio_basics.createModule(ctx),
            },
        },
    });
    module.addIncludePath(ctx.upstream.path("modules"));

    const is_darwin = ctx.target.result.os.tag.isDarwin();
    module.addCSourceFiles(.{
        .root = ctx.upstream.path("modules/juce_opengl"),
        .files = &.{ctx.builder.fmt("juce_opengl.{s}", .{if (is_darwin) "mm" else "cpp"})},
    });

    if (is_darwin) {
        darwin_sdk.addPaths(ctx.builder, module);
    }

    switch (ctx.target.result.os.tag) {
        .macos => {
            module.linkFramework("OpenGL", .{});
        },
        .ios => {
            module.linkFramework("OpenGLES", .{});
        },
        .linux => {
            module.linkSystemLibrary("gl", .{});
        },
        else => {},
    }

    ctx.visited.put(ctx.builder.allocator, juce_module.name, module) catch @panic("OOM");

    return module;
}
