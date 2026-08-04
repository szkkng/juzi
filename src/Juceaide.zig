const std = @import("std");
const darwin = @import("darwin.zig");
const Juceaide = @This();
const Setup = @import("Setup.zig");
const juce_build_tools = @import("modules/juce_build_tools.zig").juce_module;

artifact: *std.Build.Step.Compile,

pub fn create(
    b: *std.Build,
    juzi_dep: *std.Build.Dependency,
) Juceaide {
    const juce_src = juzi_dep.builder.dependency("upstream", .{});
    const target = b.graph.host;
    const optimize = .Debug;

    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });
    mod.addIncludePath(juce_src.path("modules"));
    mod.addIncludePath(juce_src.path("extras/Build"));
    mod.addCSourceFiles(.{
        .root = juce_src.path("extras/Build/juceaide"),
        .files = &.{"Main.cpp"},
    });

    if (target.result.os.tag.isDarwin()) {
        darwin.addSdkPaths(b, mod);
    }

    const juce_modules = Setup.resolveJuceModules(b, &.{juce_build_tools});
    const required_flags = Setup.resolveJuceRequiredFlags(
        b,
        target,
        optimize,
        juce_modules,
        mod.c_macros.items,
        &.{
            "-DJUCE_DISABLE_JUCE_VERSION_PRINTING=1",
            "-DJUCE_STANDALONE_APPLICATION=1",
        },
    );
    Setup.addJuceModules(mod, juce_modules, .{
        .builder = b,
        .juce = juce_src,
        .target = target,
        .optimize = optimize,
        .juce_required_flags = required_flags,
    });
    Setup.addFlagsToLinkObjects(mod, required_flags.cxx);

    const juceaide = b.addExecutable(.{
        .name = "juceaide",
        .root_module = mod,
    });

    return .{ .artifact = juceaide };
}
