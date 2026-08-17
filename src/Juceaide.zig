const std = @import("std");
const darwin = @import("darwin.zig");
const Juceaide = @This();
const setup = @import("setup.zig");
const juce_build_tools = @import("modules/juce_build_tools.zig").juce_module;

artifact: *std.Build.Step.Compile,

pub fn create(
    b: *std.Build,
    juce: *std.Build.Dependency,
) Juceaide {
    const target = if (b.graph.host.result.os.tag == .windows) b.resolveTargetQuery(.{ .abi = .msvc }) else b.graph.host;
    const optimize: std.builtin.OptimizeMode = .Debug;

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
    });
    mod.addCMacro("JUCE_DISABLE_JUCE_VERSION_PRINTING", "1");
    mod.addCMacro("JUCE_USE_CURL", "0");
    mod.addCMacro("JUCE_STANDALONE_APPLICATION", "1");

    if (target.result.os.tag.isDarwin()) {
        darwin.addSdkPaths(b, mod);
    }

    setup.addJuceStandardMacros(mod);

    const juce_modules = setup.resolveModules(b, &.{juce_build_tools});
    setup.addJuceModuleAvailableMacros(mod, juce_modules);
    const required_flags = setup.resolveRequiredFlags(
        b,
        .cxx17,
        target,
    );
    setup.addFlagsToLinkObjects(mod, required_flags.cxx);
    setup.addModules(mod, juce_modules, .{
        .builder = b,
        .juce = juce,
        .target = target,
        .optimize = optimize,
        .juce_required_flags = required_flags,
    });

    const juceaide = b.addExecutable(.{
        .name = "juceaide",
        .root_module = mod,
    });

    return .{ .artifact = juceaide };
}
