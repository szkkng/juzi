const std = @import("std");
const builtin = @import("builtin");
const Plugin = @This();
const darwin = @import("darwin.zig");
const windows = @import("windows.zig");
const Juceaide = @import("Juceaide.zig");
const BinaryData = @import("BinaryData.zig");
const vst3_manifest = @import("plugin/vst3_manifest.zig");
const getPluginMacros = @import("plugin/macros.zig").getPluginMacros;
const setup = @import("setup.zig");

pub const Format = @import("plugin/format.zig").Format;
pub const JuceModule = @import("JuceModule.zig");
pub const CxxStandard = setup.CxxStandard;
pub const Config = @import("plugin/Config.zig");

juce: *std.Build.Dependency,
root_module: *std.Build.Module,
binary_data: std.ArrayList(BinaryData.CreateOptions),
cxx_standard: CxxStandard,
config: Config,
juce_modules: []const JuceModule,

pub const InitOptions = struct {
    juzi: *std.Build.Dependency,
    config: Config.Options,
    juce_modules: []const JuceModule,
    cxx_standard: CxxStandard = .cxx17,
    target: ?std.Build.ResolvedTarget = null,
    optimize: ?std.builtin.OptimizeMode = null,
};

pub fn init(b: *std.Build, options: InitOptions) Plugin {
    const target = options.target orelse b.standardTargetOptions(.{
        .default_target = if (builtin.os.tag == .windows) .{ .abi = .msvc } else .{},
    });
    const optimize = options.optimize orelse b.standardOptimizeOption(.{});
    const isWindows = target.result.os.tag == .windows;

    if (isWindows and target.result.abi != .msvc)
        @panic("Windows builds require the MSVC ABI");

    return Plugin{
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = !isWindows,
            // Temporary disable sanitizer on Windows due to the following:
            // https://github.com/juce-framework/JUCE/issues/1697
            .sanitize_c = if (isWindows) .off else null,
        }),
        .juce = options.juzi.builder.dependency("juce", .{}),
        .cxx_standard = options.cxx_standard,
        .binary_data = .empty,
        .config = Config.init(b, options.config),
        .juce_modules = options.juce_modules,
    };
}

pub const Result = struct {
    artifacts: std.AutoHashMapUnmanaged(Format, *std.Build.Step.Compile),
    install_steps: std.AutoHashMapUnmanaged(Format, *std.Build.Step),
    binary_data: ?*std.Build.Step.Compile = null,
};

pub fn finalize(self: *Plugin) Result {
    const b = self.root_module.owner;
    const target = self.root_module.resolved_target.?;
    const optimize = self.root_module.optimize.?;
    const config = self.config;
    const juce = self.juce;
    var result: Result = .{
        .artifacts = .empty,
        .install_steps = .empty,
    };
    if (target.result.os.tag.isDarwin()) {
        darwin.addSdkPaths(b, self.root_module);
    }

    const info_text_file = setup.generateInfoText(b, config) catch @panic("Failed to generate Info.txt");
    linkOptionalLibraries(self.root_module, config);

    setup.addStandardDefs(self.root_module, optimize);
    setup.addPluginDefinitions(self.root_module, config.formats);

    var extra_flags: std.ArrayList([]const u8) = .empty;
    const plugin_macros = getPluginMacros(b, config) catch @panic("OOM");
    extra_flags.appendSlice(b.allocator, plugin_macros) catch @panic("OOM");

    const juce_modules = setup.resolveModules(b, self.juce_modules);
    const required_flags = setup.resolveRequiredFlags(
        b,
        juce_modules,
        self.cxx_standard,
        target,
        extra_flags.items,
    );
    self.root_module.addIncludePath(juce.path("modules"));
    setup.addFlagsToLinkObjects(self.root_module, required_flags.cxx);
    setup.addModules(self.root_module, juce_modules, .{
        .builder = b,
        .juce = juce,
        .target = target,
        .optimize = optimize,
        .juce_required_flags = required_flags,
    });

    const juceaide = Juceaide.create(b, juce);

    const plugin_shared_lib = b.addLibrary(.{
        .name = "plugin_shared_lib",
        .root_module = self.root_module,
    });

    if (self.binary_data.items.len > 0) {
        for (self.binary_data.items) |bd_opts| {
            const binary_data_lib = BinaryData.create(juceaide, target, optimize, bd_opts);
            for (binary_data_lib.root_module.include_dirs.items) |include_dir| {
                self.root_module.addIncludePath(include_dir.path);
            }
            result.binary_data = binary_data_lib;
            plugin_shared_lib.root_module.linkLibrary(binary_data_lib);
        }
    }

    for (config.formats) |format| {
        switch (format) {
            .vst3 => {
                const vst3_step = b.step("vst3", "Build VST3");

                // macOS: Zig doesn’t yet emit Mach‑O bundles (MH_BUNDLE) (see https://github.com/ziglang/zig/issues/14757).
                // We build an MH_DYLIB instead and install it as the bundle’s main binary.
                const vst3 = b.addLibrary(.{
                    .linkage = .dynamic,
                    .name = b.fmt("{s}", .{config.product_name}),
                    .root_module = b.createModule(.{ .target = target, .optimize = optimize }),
                    .win32_manifest = windows.createManifest(b),
                });
                setup.addStandardDefs(vst3.root_module, optimize);
                setup.addPluginDefinitions(vst3.root_module, &.{.vst3});
                vst3.root_module.c_macros.appendSlice(b.allocator, self.root_module.c_macros.items) catch @panic("OOM");
                vst3.root_module.linkLibrary(plugin_shared_lib);
                vst3.root_module.addIncludePath(juce.path("modules"));
                vst3.root_module.addIncludePath(juce.path("modules/juce_audio_processors_headless/format_types"));
                vst3.root_module.addIncludePath(juce.path("modules/juce_audio_processors_headless/format_types/VST3_SDK"));
                vst3.root_module.addCSourceFiles(.{
                    .root = juce.path("modules/juce_audio_plugin_client"),
                    .files = &.{b.fmt(
                        "juce_audio_plugin_client_VST3.{s}",
                        .{if (target.result.os.tag.isDarwin()) "mm" else "cpp"},
                    )},
                    .flags = required_flags.cxx,
                });

                const install_module_info = vst3_manifest.addInstallModuleInfo(
                    b,
                    juce,
                    vst3.name,
                    .{
                        .target = target,
                        .optimize = optimize,
                        .flags = required_flags.cxx,
                    },
                );

                switch (target.result.os.tag) {
                    .macos => {
                        darwin.addSdkPaths(b, vst3.root_module);
                        const install_vst3 = darwin.addInstallBundle(vst3, .{ .plugin = .vst3 });
                        const install_plist = darwin.addInstallInfoPlist(juceaide, info_text_file, config, .{ .plugin = .vst3 });
                        const install_pkginfo = darwin.addInstallPkgInfo(juceaide, vst3.name, .{ .plugin = .vst3 });
                        const adhoc_sign_run = darwin.addAdhocSign(
                            b,
                            b.getInstallPath(.prefix, b.fmt("{s}.vst3", .{vst3.name})),
                        );
                        adhoc_sign_run.step.dependOn(&install_plist.step);
                        adhoc_sign_run.step.dependOn(&install_pkginfo.step);
                        adhoc_sign_run.step.dependOn(&install_vst3.step);
                        if (config.vst3_auto_manifest) {
                            adhoc_sign_run.step.dependOn(&install_module_info.step);
                        }
                        vst3_step.dependOn(&adhoc_sign_run.step);
                    },
                    .linux => {
                        const bundle_subpath = b.fmt(
                            "{s}.vst3/Contents/{s}-linux",
                            .{ config.product_name, @tagName(target.result.cpu.arch) },
                        );
                        const install_vst3 = b.addInstallArtifact(vst3, .{
                            .dest_dir = .{ .override = .{ .custom = bundle_subpath } },
                            .dest_sub_path = b.fmt("{s}.vst3", .{vst3.name}),
                        });
                        if (config.vst3_auto_manifest) {
                            vst3_step.dependOn(&install_module_info.step);
                        }
                        vst3_step.dependOn(&install_vst3.step);
                    },
                    .windows => {
                        vst3.root_module.linkSystemLibrary("oldnames", .{});
                        windows.addResourcesRc(vst3.root_module, juceaide, info_text_file);
                        const arch_str = switch (target.result.cpu.arch) {
                            .x86_64 => "x86_64",
                            .x86 => "x86",
                            .aarch64 => "arm64",
                            else => |arch| @panic(b.fmt("unsupported architecture for VST3: {s}", .{@tagName(arch)})),
                        };
                        const bundle_subpath = b.fmt(
                            "{s}.vst3/Contents/{s}-win",
                            .{ config.product_name, arch_str },
                        );
                        const install_vst3 = b.addInstallArtifact(vst3, .{
                            .dest_dir = .{ .override = .{ .custom = bundle_subpath } },
                            .dest_sub_path = b.fmt("{s}.vst3", .{vst3.name}),
                        });
                        if (config.vst3_auto_manifest) {
                            vst3_step.dependOn(&install_module_info.step);
                        }
                        vst3_step.dependOn(&install_vst3.step);
                    },
                    else => @panic("unsupported os"),
                }

                result.artifacts.put(b.allocator, .vst3, vst3) catch @panic("OOM");
                result.install_steps.put(b.allocator, .vst3, vst3_step) catch @panic("OOM");
            },
            .au => {
                if (!target.result.os.tag.isDarwin()) {
                    continue;
                }

                const au_step = b.step("au", "Build AU");

                // macOS: Zig doesn’t yet emit Mach‑O bundles (MH_BUNDLE) (see https://github.com/ziglang/zig/issues/14757).
                // We build an MH_DYLIB instead and install it as the bundle’s main binary.
                const au = b.addLibrary(.{
                    .linkage = .dynamic,
                    .name = b.fmt("{s}", .{config.product_name}),
                    .root_module = b.createModule(.{ .target = target, .optimize = optimize }),
                });
                darwin.addSdkPaths(b, au.root_module);
                setup.addStandardDefs(au.root_module, optimize);
                setup.addPluginDefinitions(au.root_module, &.{.au});
                au.root_module.c_macros.appendSlice(b.allocator, self.root_module.c_macros.items) catch @panic("OOM");
                au.root_module.linkLibrary(plugin_shared_lib);
                au.root_module.addIncludePath(juce.path("modules"));
                au.root_module.addIncludePath(juce.path("modules/juce_audio_plugin_client/AU"));
                au.root_module.addCSourceFiles(.{
                    .root = juce.path("modules/juce_audio_plugin_client"),
                    .files = &.{
                        "juce_audio_plugin_client_AU_1.mm",
                        "juce_audio_plugin_client_AU_2.mm",
                    },
                    .flags = required_flags.cxx,
                });

                const install_au = darwin.addInstallBundle(au, .{ .plugin = .au });
                const install_plist = darwin.addInstallInfoPlist(juceaide, info_text_file, config, .{ .plugin = .au });
                const install_pkginfo = darwin.addInstallPkgInfo(juceaide, au.name, .{ .plugin = .au });
                const adhoc_sign = darwin.addAdhocSign(
                    b,
                    b.getInstallPath(.prefix, b.fmt("{s}.component", .{au.name})),
                );
                adhoc_sign.step.dependOn(&install_plist.step);
                adhoc_sign.step.dependOn(&install_pkginfo.step);
                adhoc_sign.step.dependOn(&install_au.step);
                au_step.dependOn(&adhoc_sign.step);

                result.artifacts.put(b.allocator, .au, au) catch @panic("OOM");
                result.install_steps.put(b.allocator, .au, au_step) catch @panic("OOM");
            },
            .standalone => {
                const standalone_step = b.step("standalone", "Build standalone");
                const standalone = b.addExecutable(.{
                    .name = config.product_name,
                    .root_module = b.createModule(.{ .target = target, .optimize = optimize }),
                    .win32_manifest = windows.createManifest(b),
                });
                setup.addStandardDefs(standalone.root_module, optimize);
                setup.addPluginDefinitions(standalone.root_module, &.{.standalone});
                standalone.root_module.c_macros.appendSlice(b.allocator, self.root_module.c_macros.items) catch @panic("OOM");
                standalone.root_module.linkLibrary(plugin_shared_lib);
                standalone.root_module.addIncludePath(juce.path("modules"));
                standalone.root_module.addCSourceFiles(.{
                    .root = juce.path("modules/juce_audio_plugin_client"),
                    .files = &.{"juce_audio_plugin_client_Standalone.cpp"},
                    .flags = required_flags.cxx,
                });

                switch (target.result.os.tag) {
                    .macos => {
                        darwin.addSdkPaths(b, standalone.root_module);
                        const install_standalone = darwin.addInstallBundle(standalone, .{ .plugin = .standalone });
                        const install_plist = darwin.addInstallInfoPlist(juceaide, info_text_file, config, .{ .plugin = .standalone });
                        const install_pkginfo = darwin.addInstallPkgInfo(juceaide, config.product_name, .{ .plugin = .standalone });
                        const install_nib = darwin.addInstallNib(b, juce, config.product_name, .{ .plugin = .standalone });

                        standalone_step.dependOn(&install_standalone.step);
                        standalone.step.dependOn(&install_plist.step);
                        standalone_step.dependOn(&install_pkginfo.step);
                        standalone_step.dependOn(&install_nib.step);
                    },
                    .linux => {
                        const install_standalone = b.addInstallArtifact(standalone, .{});
                        standalone_step.dependOn(&install_standalone.step);
                    },
                    .windows => {
                        windows.addResourcesRc(standalone.root_module, juceaide, info_text_file);
                        const install_standalone = b.addInstallArtifact(standalone, .{});
                        standalone_step.dependOn(&install_standalone.step);
                    },
                    else => @panic("unsupported os"),
                }

                const run_cmd = b.addRunArtifact(standalone);
                run_cmd.step.dependOn(standalone_step);
                const run_step = b.step("run", "Run standalone");
                run_step.dependOn(&run_cmd.step);

                result.artifacts.put(b.allocator, .standalone, standalone) catch @panic("OOM");
                result.install_steps.put(b.allocator, .standalone, standalone_step) catch @panic("OOM");
            },
        }
    }

    return result;
}

pub fn addBinaryData(self: *Plugin, bd: BinaryData.CreateOptions) void {
    const b = self.root_module.owner;
    self.binary_data.append(b.allocator, bd) catch @panic("OOM");
}

fn linkOptionalLibraries(m: *std.Build.Module, config: Config) void {
    const os_tag = m.resolved_target.?.result.os.tag;
    switch (os_tag) {
        .linux => {
            if (config.needs_curl) {
                m.linkSystemLibrary("curl", .{});
            }

            if (config.needs_web_browser) {
                // TODO: Implement logic equivalent to JUCE's
                // _juce_available_pkgconfig_module_or_else(webkit_package_name webkit2gtk-4.1 webkit2gtk-4.0)
                m.linkSystemLibrary("webkit2gtk-4.1", .{});
                // m.linkSystemLibrary("webkit2gtk-4.0", .{});

                m.linkSystemLibrary("gtk+-x11-3.0", .{});
            }
        },
        .macos, .ios => {
            m.addCMacro("JUCE_IN_APP_PURCHASES", if (config.needs_store_kit) "1" else "0");

            if (config.needs_store_kit) {
                m.linkFramework("StoreKit", .{});
            }

            if (config.camera_permission_enabled) |is_enabled| {
                if (os_tag == .ios and is_enabled) {
                    m.linkFramework("ImageIO", .{});
                }
            }
        },
        .windows => {
            // TODO
        },
        else => {},
    }
}
