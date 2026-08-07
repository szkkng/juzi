const std = @import("std");
const darwin = @import("../darwin.zig");
const setup = @import("../setup.zig");

const AddInstallModuleInfoOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    flags: []const []const u8 = &.{},
};

// Creates the install step for generating and installing the VST3 moduleinfo.json file.
pub fn addInstallModuleInfo(
    b: *std.Build,
    juce: *std.Build.Dependency,
    product_name: []const u8,
    options: AddInstallModuleInfoOptions,
) *std.Build.Step.InstallFile {
    const manifest_helper = b.addExecutable(.{
        .name = "juce_vst3_manifest_helper",
        .root_module = b.createModule(.{
            .target = options.target,
            .optimize = options.optimize,
            .link_libc = true,
            .link_libcpp = options.target.result.os.tag != .windows,
        }),
    });
    manifest_helper.root_module.addIncludePath(juce.path("modules"));
    manifest_helper.root_module.addIncludePath(juce.path("modules/juce_audio_processors_headless/format_types/VST3_SDK"));
    manifest_helper.root_module.addCSourceFiles(.{
        .root = juce.path("modules/juce_audio_plugin_client/VST3"),
        .files = &.{"juce_VST3ManifestHelper.cpp"},
        .flags = options.flags,
    });

    const manifest_helper_cmd = b.addRunArtifact(manifest_helper);
    const out_module_info = manifest_helper_cmd.captureStdOut(.{});
    const install_module_info = b.addInstallFileWithDir(
        out_module_info,
        .prefix,
        b.fmt("{s}.vst3/Contents/Resources/moduleinfo.json", .{product_name}),
    );
    setup.addStandardDefs(manifest_helper.root_module, options.optimize);

    switch (options.target.result.os.tag) {
        .macos => {
            manifest_helper.root_module.linkFramework("Foundation", .{});
            darwin.addSdkPaths(b, manifest_helper.root_module);
        },
        .windows => {
            manifest_helper.root_module.linkSystemLibrary("ole32", .{});
        },
        else => {},
    }

    return install_module_info;
}
