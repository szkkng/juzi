const std = @import("std");
const Plugin = @This();
const darwin = @import("darwin.zig");
const windows = @import("windows.zig");
const Juceaide = @import("Juceaide.zig");
const BinaryData = @import("BinaryData.zig");
const Vst3Manifest = @import("plugin/vst3_manifest.zig");
const PluginMacros = @import("plugin/macros.zig");
const setup = @import("setup.zig");

pub const Format = @import("plugin/format.zig").Format;
pub const JuceModule = @import("JuceModule.zig");
pub const CxxStandard = setup.CxxStandard;
pub const Config = @import("plugin/Config.zig");

juce: *std.Build.Dependency,
root_module: *std.Build.Module,
juce_macros: std.ArrayList([]const u8),
binary_data: std.ArrayList(BinaryData.CreateOptions),
cxx_standard: CxxStandard,
config: Config,
juce_modules: []const JuceModule,

pub const InitOptions = struct {
    juzi: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    config: Config.Options,
    juce_modules: []const JuceModule,
    cxx_standard: CxxStandard = .cxx17,
};

pub fn init(b: *std.Build, options: InitOptions) Plugin {
    const isWindows = options.target.result.os.tag == .windows;

    if (isWindows and options.target.result.abi != .msvc)
        @panic("Windows builds require the MSVC ABI");

    return Plugin{
        .root_module = b.createModule(.{
            .target = options.target,
            .optimize = options.optimize,
            .link_libc = true,
            .link_libcpp = !isWindows,
            // Temporary disable sanitizer on Windows due to the following:
            // https://github.com/juce-framework/JUCE/issues/1697
            .sanitize_c = if (isWindows) .off else null,
        }),
        .juce = options.juzi.builder.dependency("juce", .{}),
        .juce_macros = .empty,
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
    const optimize = self.root_module.optimize orelse .Debug;
    const juce = self.juce;
    var result: Result = .{
        .artifacts = .empty,
        .install_steps = .empty,
    };
    if (target.result.os.tag.isDarwin()) {
        darwin.addSdkPaths(b, self.root_module);
    }

    setup.addStandardDefs(self.root_module, optimize);
    setup.addPluginDefinitions(self.root_module, self.config.formats);

    var extra_flags = std.ArrayList([]const u8).empty;
    extra_flags.appendSlice(b.allocator, self.juce_macros.items) catch @panic("OOM");
    const plugin_macros = PluginMacros.getPluginMacros(b, self.config) catch @panic("OOM");
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
    linkOptionalLibraries(plugin_shared_lib.root_module, self.config);

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

    const config = self.config;
    const info_text_file = setup.generateInfoText(b, config) catch @panic("Failed to generate Info.txt");

    for (config.formats) |format| {
        switch (format) {
            .vst3 => {
                var flags: std.ArrayList([]const u8) = .empty;
                flags.appendSlice(b.allocator, required_flags.cxx) catch @panic("OOM");

                const vst3_module = b.createModule(.{
                    .target = target,
                    .optimize = optimize,
                });
                setup.addStandardDefs(vst3_module, optimize);
                setup.addPluginDefinitions(vst3_module, &.{.vst3});
                vst3_module.addIncludePath(juce.path("modules"));
                vst3_module.addIncludePath(juce.path("modules/juce_audio_processors_headless/format_types"));
                vst3_module.addIncludePath(juce.path("modules/juce_audio_processors_headless/format_types/VST3_SDK"));

                const is_darwin = target.result.os.tag.isDarwin();
                vst3_module.addCSourceFiles(.{
                    .root = juce.path("modules"),
                    .files = &.{b.fmt(
                        "juce_audio_plugin_client/juce_audio_plugin_client_VST3.{s}",
                        .{if (is_darwin) "mm" else "cpp"},
                    )},
                    .flags = flags.items,
                });

                switch (target.result.os.tag) {
                    .macos => darwin.addSdkPaths(b, vst3_module),
                    .windows => vst3_module.linkSystemLibrary("oldnames", .{}),
                    else => {},
                }

                const vst3_step = b.step("vst3", "Build VST3");

                // macOS: Zig doesn’t yet emit Mach‑O bundles (MH_BUNDLE) (see https://github.com/ziglang/zig/issues/14757).
                // We build an MH_DYLIB instead and install it as the bundle’s main binary.
                // Many hosts may accept this, but MH_BUNDLE is the conventional VST3 format.
                // Once Zig supports MH_BUNDLE, switch to it and remove this workaround.
                const vst3 = b.addLibrary(.{
                    .linkage = .dynamic,
                    .name = b.fmt("{s}", .{config.product_name}),
                    .root_module = vst3_module,
                    .win32_manifest = windows.createManifest(b),
                });
                vst3.root_module.linkLibrary(plugin_shared_lib);

                switch (target.result.os.tag) {
                    .macos => {
                        const install_vst3 = darwin.addInstallBundle(vst3, .{ .plugin = .vst3 });
                        const codesign_run = darwin.addAdhocCodesign(
                            b,
                            b.getInstallPath(.prefix, b.fmt("{s}.vst3", .{vst3.name})),
                        );
                        codesign_run.step.dependOn(&install_vst3.step);
                        vst3_step.dependOn(&codesign_run.step);

                        const install_plist = darwin.addInstallInfoPlist(juceaide, info_text_file, config, .{ .plugin = .vst3 });
                        const install_pkginfo = darwin.addInstallPkgInfo(juceaide, vst3.name, .{ .plugin = .vst3 });
                        vst3_step.dependOn(&install_plist.step);
                        vst3_step.dependOn(&install_pkginfo.step);
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
                        vst3_step.dependOn(&install_vst3.step);
                    },
                    .windows => {
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
                        windows.addResourcesRc(vst3.root_module, juceaide, info_text_file);
                        vst3_step.dependOn(&install_vst3.step);
                    },
                    else => @panic("Not implemented yet"),
                }

                if (config.vst3_auto_manifest) {
                    const install_module_info = Vst3Manifest.addInstallModuleInfo(
                        b,
                        juce,
                        vst3.name,
                        .{
                            .target = target,
                            .optimize = optimize,
                            .flags = flags.items,
                        },
                    );
                    vst3_step.dependOn(&install_module_info.step);
                }

                result.artifacts.put(b.allocator, .vst3, vst3) catch @panic("OOM");
                result.install_steps.put(b.allocator, .vst3, vst3_step) catch @panic("OOM");
            },
            .au => {
                if (!target.result.os.tag.isDarwin()) {
                    continue;
                }

                var flags: std.ArrayList([]const u8) = .empty;
                flags.appendSlice(b.allocator, required_flags.cxx) catch @panic("OOM");

                const au_module = b.createModule(.{
                    .target = target,
                    .optimize = optimize,
                });
                setup.addStandardDefs(au_module, optimize);
                setup.addPluginDefinitions(au_module, &.{.au});
                au_module.addIncludePath(juce.path("modules"));
                au_module.addIncludePath(juce.path("modules/juce_audio_plugin_client/AU"));
                au_module.addCSourceFiles(.{
                    .root = juce.path("modules"),
                    .files = &.{
                        "juce_audio_plugin_client/juce_audio_plugin_client_AU_1.mm",
                        "juce_audio_plugin_client/juce_audio_plugin_client_AU_2.mm",
                    },
                    .flags = flags.items,
                });

                if (target.result.os.tag.isDarwin()) {
                    darwin.addSdkPaths(b, au_module);
                }

                const au_step = b.step("au", "Build AU");

                // macOS: Zig doesn’t yet emit Mach‑O bundles (MH_BUNDLE) (see https://github.com/ziglang/zig/issues/14757).
                // We build an MH_DYLIB instead and install it as the bundle’s main binary.
                // Many hosts may accept this, but MH_BUNDLE is the conventional AU format.
                // Once Zig supports MH_BUNDLE, switch to it and remove this workaround.
                const au = b.addLibrary(.{
                    .linkage = .dynamic,
                    .name = b.fmt("{s}", .{config.product_name}),
                    .root_module = au_module,
                });
                au.root_module.linkLibrary(plugin_shared_lib);

                const install_au = darwin.addInstallBundle(au, .{ .plugin = .au });
                const codesign_run = darwin.addAdhocCodesign(
                    b,
                    b.getInstallPath(.prefix, b.fmt("{s}.component", .{au.name})),
                );
                codesign_run.step.dependOn(&install_au.step);
                au_step.dependOn(&codesign_run.step);

                const install_plist = darwin.addInstallInfoPlist(juceaide, info_text_file, config, .{ .plugin = .au });
                const install_pkginfo = darwin.addInstallPkgInfo(juceaide, au.name, .{ .plugin = .au });
                au_step.dependOn(&install_plist.step);
                au_step.dependOn(&install_pkginfo.step);

                result.artifacts.put(b.allocator, .au, au) catch @panic("OOM");
                result.install_steps.put(b.allocator, .au, au_step) catch @panic("OOM");
            },
            .standalone => {
                var flags: std.ArrayList([]const u8) = .empty;
                flags.appendSlice(b.allocator, required_flags.cxx) catch @panic("OOM");

                const standalone_module = b.createModule(.{
                    .target = target,
                    .optimize = optimize,
                });
                setup.addStandardDefs(standalone_module, optimize);
                setup.addPluginDefinitions(standalone_module, &.{.standalone});
                standalone_module.addIncludePath(juce.path("modules"));
                standalone_module.addCSourceFiles(.{
                    .root = juce.path("modules"),
                    .files = &.{
                        "juce_audio_plugin_client/juce_audio_plugin_client_Standalone.cpp",
                    },
                    .flags = flags.items,
                });

                if (target.result.os.tag.isDarwin()) {
                    darwin.addSdkPaths(b, standalone_module);
                }

                const standalone = b.addExecutable(.{
                    .name = config.product_name,
                    .root_module = standalone_module,
                    .win32_manifest = windows.createManifest(b),
                });
                standalone.root_module.linkLibrary(plugin_shared_lib);

                const standalone_step = b.step("standalone", "Build standalone");

                switch (target.result.os.tag) {
                    .macos => {
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
                    else => @panic("Not implemented yet"),
                }

                const run_cmd = b.addRunArtifact(standalone);
                run_cmd.step.dependOn(standalone_step);
                const run_step = b.step("run", "Run standalone");
                run_step.dependOn(&run_cmd.step);

                result.artifacts.put(b.allocator, .standalone, standalone) catch @panic("OOM");
                result.install_steps.put(b.allocator, .standalone, standalone_step) catch @panic("OOM");
            },
            // else => @panic("Not implemented yet"),
        }
    }

    return result;
}

// Similar to `std.Build.Module.addCMacro`, but for defining
// JUCE_* macros that apply to all JUCE-related compilation,
// not just the root module.
pub fn addJuceMacro(self: *Plugin, name: []const u8, value: []const u8) void {
    const b = self.root_module.owner;
    self.juce_macros.append(b.allocator, b.fmt("-D{s}={s}", .{ name, value })) catch @panic("OOM");
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
        else => {
            if (os_tag.isDarwin()) {
                // TODO: Link StoreKit and ImageIO when needed.
            }
        },
    }
}
