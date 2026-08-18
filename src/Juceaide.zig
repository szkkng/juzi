const std = @import("std");
const darwin = @import("darwin.zig");
const Juceaide = @This();
const JuceModule = @import("JuceModule.zig");
const setup = @import("setup.zig");

artifact: *std.Build.Step.Compile,

pub fn create(
    b: *std.Build,
    juce: *std.Build.Dependency,
) Juceaide {
    const target = if (b.graph.host.result.os.tag == .windows) b.resolveTargetQuery(.{ .abi = .msvc }) else b.graph.host;
    const optimize: std.builtin.OptimizeMode = .Debug;
    const cxx_standard: setup.CxxStandard = .cxx17;

    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = target.result.os.tag != .windows,
    });
    mod.addIncludePath(juce.path("modules"));
    mod.addIncludePath(juce.path("extras/Build"));
    mod.addCSourceFiles(.{
        .root = juce.path("extras/Build/juceaide"),
        .files = &.{"Main.cpp"},
        .flags = &.{cxx_standard.flag()},
    });
    mod.addCMacro("JUCE_DISABLE_JUCE_VERSION_PRINTING", "1");
    mod.addCMacro("JUCE_USE_CURL", "0");
    mod.addCMacro("JUCE_STANDALONE_APPLICATION", "1");

    if (target.result.os.tag.isDarwin()) {
        darwin.addSdkPaths(b, mod);
    }

    setup.addJuceStandardMacros(mod);

    setup.addJuceModules(mod, &.{juce_build_tools}, .{
        .builder = b,
        .juce = juce,
        .target = target,
        .optimize = optimize,
        .cxx_standard = cxx_standard,
    });

    const juceaide = b.addExecutable(.{
        .name = "juceaide",
        .root_module = mod,
    });

    return .{ .artifact = juceaide };
}

pub const juce_build_tools: JuceModule = .{
    .name = "juce_build_tools",
    .deps = &.{@import("modules/juce_graphics.zig").juce_module},
    .configure = struct {
        fn f(root_module: *std.Build.Module, ctx: JuceModule.BuildContext) void {
            root_module.addIncludePath(ctx.juce.path("extras/Build/juce_build_tools"));
            root_module.addCSourceFiles(.{
                .root = ctx.juce.path("extras/Build/juce_build_tools"),
                .files = &.{"juce_build_tools.cpp"},
                .flags = ctx.cxxFlags(&.{}),
            });
        }
    }.f,
};
