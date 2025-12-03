const std = @import("std");
const darwin = @import("../darwin.zig");

const AddInstallModuleInfoOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    flags: []const []const u8 = &.{},
};

// Creates the install step for generating and installing the VST3 moduleinfo.json file.
pub fn addInstallModuleInfo(
    b: *std.Build,
    upstream: *std.Build.Dependency,
    product_name: []const u8,
    options: AddInstallModuleInfoOptions,
) *std.Build.Step.InstallFile {
    const manifest_helper = b.addExecutable(.{
        .name = "juce_vst3_manifest_helper",
        .root_module = b.createModule(.{
            .target = options.target,
            .optimize = options.optimize,
            .link_libcpp = true,
        }),
    });
    manifest_helper.root_module.addIncludePath(upstream.path("modules"));
    manifest_helper.root_module.addIncludePath(upstream.path("modules/juce_audio_processors_headless/format_types/VST3_SDK"));
    const is_darwin = options.target.result.os.tag.isDarwin();
    manifest_helper.root_module.addCSourceFiles(.{
        .root = upstream.path("modules/juce_audio_plugin_client/VST3"),
        .files = &.{b.fmt("juce_VST3ManifestHelper.{s}", .{if (is_darwin) "mm" else "cpp"})},
        .flags = options.flags,
    });

    const manifest_helper_cmd = b.addRunArtifact(manifest_helper);
    const out_module_info = manifest_helper_cmd.captureStdOut();
    const install_module_info = b.addInstallFileWithDir(
        out_module_info,
        .prefix,
        b.fmt("{s}.vst3/Contents/Resources/moduleinfo.json", .{product_name}),
    );

    if (is_darwin) {
        manifest_helper.root_module.linkFramework("Foundation", .{});
        darwin.sdk.addPaths(b, manifest_helper.root_module);
    }

    return install_module_info;
}
