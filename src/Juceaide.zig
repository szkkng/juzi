const std = @import("std");
const darwin = @import("darwin.zig");
const Juceaide = @This();
const Setup = @import("Setup.zig");
const juce_build_tools = @import("modules/juce_build_tools.zig").juce_module;

artifact: *std.Build.Step.Compile,

pub fn create(
    b: *std.Build,
    juce: *std.Build.Dependency,
) Juceaide {
    const target = b.graph.host;
    const optimize = .Debug;

    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });
    mod.addIncludePath(juce.path("modules"));
    mod.addIncludePath(juce.path("extras/Build"));
    mod.addCSourceFiles(.{
        .root = juce.path("extras/Build/juceaide"),
        .files = &.{"Main.cpp"},
    });

    if (target.result.os.tag.isDarwin()) {
        darwin.addSdkPaths(b, mod);
    }

    Setup.addJuceStandardDefs(mod, optimize);

    const juce_modules = Setup.resolveJuceModules(b, &.{juce_build_tools});
    const required_flags = Setup.resolveJuceRequiredFlags(
        b,
        juce_modules,
        .cxx17,
        &.{
            "-DJUCE_DISABLE_JUCE_VERSION_PRINTING=1",
            "-DJUCE_STANDALONE_APPLICATION=1",
        },
    );
    Setup.addFlagsToLinkObjects(mod, required_flags.cxx);
    Setup.addJuceModules(mod, juce_modules, .{
        .builder = b,
        .juce = juce,
        .target = target,
        .juce_required_flags = required_flags,
    });

    const juceaide = b.addExecutable(.{
        .name = "juceaide",
        .root_module = mod,
    });

    return .{ .artifact = juceaide };
}
