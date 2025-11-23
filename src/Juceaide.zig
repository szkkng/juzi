const std = @import("std");
const Juceaide = @This();

upstream: *std.Build.Dependency,
target: std.Build.ResolvedTarget,
optimize: std.builtin.OptimizeMode,
artifact: *std.Build.Step.Compile,
juce_modules_lib: *std.Build.Step.Compile,

pub const InitOptions = struct {
    upstream: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    juce_modules_lib: *std.Build.Step.Compile,
};

pub fn create(
    b: *std.Build,
    options: InitOptions,
) Juceaide {
    const juceaide = b.addExecutable(.{
        .name = "juceaide",
        .root_module = b.createModule(.{
            .target = options.target,
            .optimize = options.optimize,
            .link_libcpp = true,
        }),
    });
    juceaide.root_module.linkLibrary(options.juce_modules_lib);
    juceaide.root_module.addIncludePath(options.upstream.path("modules"));
    juceaide.root_module.addIncludePath(options.upstream.path("extras/Build"));
    juceaide.root_module.addCSourceFiles(.{
        .root = options.upstream.path("extras/Build/juceaide"),
        .files = &.{"Main.cpp"},
    });

    return .{
        .upstream = options.upstream,
        .target = options.target,
        .optimize = options.optimize,
        .juce_modules_lib = options.juce_modules_lib,
        .artifact = juceaide,
    };
}
