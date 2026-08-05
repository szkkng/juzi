const std = @import("std");
const Setup = @This();
const darwin = @import("darwin.zig");
const Juceaide = @import("Juceaide.zig");
const BinaryData = @import("BinaryData.zig");
const Vst3Manifest = @import("plugin/vst3_manifest.zig");
const PluginMacros = @import("plugin/macros.zig");
const ProjectConfig = @import("ProjectConfig.zig");

pub const PluginFormat = @import("plugin/format.zig").PluginFormat;
pub const JuceModule = @import("JuceModule.zig");
pub const JuceModuleMap = std.StringHashMapUnmanaged(JuceModule);

juce: *std.Build.Dependency,
root_module: *std.Build.Module,
juce_macros: std.ArrayList([]const u8),
binary_data: std.ArrayList(BinaryData.CreateOptions),
cxx_standard: CxxStandard,

pub const CxxStandard = enum {
    cxx17,
    cxx20,
    cxx23,

    pub fn flag(self: CxxStandard) []const u8 {
        return switch (self) {
            .cxx17 => "--std=c++17",
            .cxx20 => "--std=c++20",
            .cxx23 => "--std=c++23",
        };
    }
};

pub const InitOptions = struct {
    juzi: *std.Build.Dependency,
    root_module: *std.Build.Module,
    cxx_standard: CxxStandard = .cxx17,
};

pub fn init(options: InitOptions) Setup {
    return Setup{
        .root_module = options.root_module,
        .juce = options.juzi.builder.dependency("juce", .{}),
        .juce_macros = .empty,
        .cxx_standard = options.cxx_standard,
        .binary_data = .empty,
    };
}

pub const AddOptions = struct {
    juce_modules: []const JuceModule,
    config: ProjectConfig,
};

pub const Plugin = struct {
    artifacts: std.AutoHashMapUnmanaged(PluginFormat, *std.Build.Step.Compile),
    install_steps: std.AutoHashMapUnmanaged(PluginFormat, *std.Build.Step),
    binary_data: ?*std.Build.Step.Compile = null,
};

pub fn addPlugin(
    self: Setup,
    options: AddOptions,
) Plugin {
    const b = self.root_module.owner;
    const target = self.root_module.resolved_target.?;
    const optimize = self.root_module.optimize orelse .Debug;
    const juce = self.juce;
    var result: Plugin = .{
        .artifacts = .empty,
        .install_steps = .empty,
    };
    addJuceStandardDefs(self.root_module, optimize);

    var extra_flags = std.ArrayList([]const u8).empty;
    extra_flags.appendSlice(b.allocator, self.juce_macros.items) catch @panic("OOM");
    const plugin_macros = PluginMacros.getPluginMacros(b, options.config) catch @panic("OOM");
    extra_flags.appendSlice(b.allocator, plugin_macros) catch @panic("OOM");

    const juce_modules = resolveJuceModules(b, options.juce_modules);
    const required_flags = resolveJuceRequiredFlags(
        b,
        juce_modules,
        self.cxx_standard,
        self.root_module.c_macros.items,
        extra_flags.items,
    );
    addJuceModules(self.root_module, juce_modules, .{
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
    self.root_module.addIncludePath(juce.path("modules"));
    linkOptionalLibraries(plugin_shared_lib.root_module, options.config);
    addFlagsToLinkObjects(plugin_shared_lib.root_module, required_flags.cxx);

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

    if (target.result.os.tag.isDarwin()) {
        darwin.addSdkPaths(b, plugin_shared_lib.root_module);
    }

    const config = options.config;

    for (config.formats) |format| {
        switch (format) {
            .vst3 => {
                var flags = std.ArrayList([]const u8).empty;
                flags.appendSlice(b.allocator, required_flags.cxx) catch @panic("OOM");
                flags.append(b.allocator, "-DJucePlugin_Build_VST3=1") catch @panic("OOM");
                const vst3_module = b.createModule(.{
                    .target = target,
                    .optimize = optimize,
                    .link_libcpp = true,
                });
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
                if (target.result.os.tag.isDarwin()) {
                    darwin.addSdkPaths(b, vst3_module);
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

                        const install_plist = darwin.addInstallInfoPlist(juceaide, config, .{ .plugin = .vst3 });
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
                            .dest_sub_path = b.fmt("{s}.so", .{vst3.name}),
                        });
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

                var flags = std.ArrayList([]const u8).empty;
                flags.appendSlice(b.allocator, required_flags.cxx) catch @panic("OOM");
                flags.append(b.allocator, "-DJucePlugin_Build_AU=1") catch @panic("OOM");
                const au_module = b.createModule(.{
                    .target = target,
                    .optimize = optimize,
                    .link_libcpp = true,
                });
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

                const install_plist = darwin.addInstallInfoPlist(juceaide, config, .{ .plugin = .au });
                const install_pkginfo = darwin.addInstallPkgInfo(juceaide, au.name, .{ .plugin = .au });
                au_step.dependOn(&install_plist.step);
                au_step.dependOn(&install_pkginfo.step);

                result.artifacts.put(b.allocator, .au, au) catch @panic("OOM");
                result.install_steps.put(b.allocator, .au, au_step) catch @panic("OOM");
            },
            .standalone => {
                var flags = std.ArrayList([]const u8).empty;
                flags.appendSlice(b.allocator, required_flags.cxx) catch @panic("OOM");
                flags.append(b.allocator, "-DJucePlugin_Build_Standalone=1") catch @panic("OOM");

                const standalone_module = b.createModule(.{
                    .target = target,
                    .optimize = optimize,
                    .link_libcpp = true,
                });
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
                });
                standalone.root_module.linkLibrary(plugin_shared_lib);

                const standalone_step = b.step("standalone", "Build standalone");

                switch (target.result.os.tag) {
                    .macos => {
                        const install_standalone = darwin.addInstallBundle(standalone, .{ .plugin = .standalone });
                        const install_plist = darwin.addInstallInfoPlist(juceaide, options.config, .{ .plugin = .standalone });
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

pub fn resolveJuceModules(
    b: *std.Build,
    requested_modules: []const JuceModule,
) JuceModuleMap {
    var modules: JuceModuleMap = .empty;

    for (requested_modules) |juce_module| {
        collectJuceModule(b, &modules, juce_module);
    }

    return modules;
}

pub fn addJuceModules(
    root_module: *std.Build.Module,
    modules: JuceModuleMap,
    ctx: JuceModule.BuildContext,
) void {
    var iterator = modules.valueIterator();
    while (iterator.next()) |module| {
        const juce_module = module.*;
        if (root_module.import_table.contains(juce_module.name)) continue;

        root_module.addImport(juce_module.name, juce_module.create(ctx));
    }
}

fn collectJuceModule(
    b: *std.Build,
    modules: *JuceModuleMap,
    juce_module: JuceModule,
) void {
    if (modules.contains(juce_module.name)) return;

    modules.put(b.allocator, juce_module.name, juce_module) catch @panic("OOM");
    for (juce_module.deps) |dependency| {
        collectJuceModule(b, modules, dependency);
    }
}

// Similar to `std.Build.Module.addCMacro`, but for defining
// JUCE_* macros that apply to all JUCE-related compilation,
// not just the root module.
pub fn addJuceMacro(self: *Setup, name: []const u8, value: []const u8) void {
    const b = self.root_module.owner;
    self.juce_macros.append(b.allocator, b.fmt("-D{s}={s}", .{ name, value })) catch @panic("OOM");
}

pub fn addBinaryData(self: *Setup, bd: BinaryData.CreateOptions) void {
    const b = self.root_module.owner;
    self.binary_data.append(b.allocator, bd) catch @panic("OOM");
}

fn linkOptionalLibraries(m: *std.Build.Module, config: ProjectConfig) void {
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

pub fn resolveJuceRequiredFlags(
    b: *std.Build,
    modules: JuceModuleMap,
    cxx_standard: CxxStandard,
    root_macros: []const []const u8,
    extra_flags: []const []const u8,
) JuceModule.RequiredFlags {
    var common: std.ArrayList([]const u8) = .empty;
    common.appendSlice(b.allocator, root_macros) catch @panic("OOM");
    common.appendSlice(b.allocator, extra_flags) catch @panic("OOM");
    common.appendSlice(b.allocator, getJuceModuleAvailableDefs(b, modules)) catch @panic("OOM");
    common.append(b.allocator, "-fvisibility=hidden") catch @panic("OOM");

    const c_flags = common.toOwnedSlice(b.allocator) catch @panic("OOM");

    var cxx: std.ArrayList([]const u8) = .empty;
    cxx.appendSlice(b.allocator, c_flags) catch @panic("OOM");
    cxx.append(b.allocator, "-fvisibility-inlines-hidden") catch @panic("OOM");
    cxx.append(b.allocator, cxx_standard.flag()) catch @panic("OOM");

    // Zig enforces -Werror=date-time in release builds for reproducible builds,
    // but juce_core_CompilationTime.cpp uses __DATE__/__TIME__.
    // Disable this error as a workaround to allow JUCE to build.
    // https://github.com/ziglang/zig/pull/20821/commits/ff7bdbbd7d997b22f50704c5268839bea9321088
    cxx.append(b.allocator, "-Wno-error=date-time") catch @panic("OOM");

    // JUCE's AU plugin client can use enum values outside the usual range,
    // which trips UBSan's enum checks when loading debug AU plugins.
    // Zig enables these UBSan checks by default, so disable them here.
    // https://github.com/juce-framework/JUCE/blob/1b460fe0895635a2ab8ac5c00cb5575e33e5dc1e/modules/juce_audio_plugin_client/juce_audio_plugin_client_AU_1.mm#L944
    cxx.append(b.allocator, "-fno-sanitize=enum") catch @panic("OOM");

    return .{
        .c = c_flags,
        .cxx = cxx.toOwnedSlice(b.allocator) catch @panic("OOM"),
    };
}

pub fn addJuceStandardDefs(mod: *std.Build.Module, optimize: std.builtin.OptimizeMode) void {
    mod.addCMacro("JUCE_GLOBAL_MODULE_SETTINGS_INCLUDED", "1");

    if (optimize == .Debug) {
        mod.addCMacro("DEBUG", "1");
        mod.addCMacro("_DEBUG", "1");
    } else {
        mod.addCMacro("NDEBUG", "1");
        mod.addCMacro("_NDEBUG", "1");
    }
}

pub fn getJuceModuleAvailableDefs(
    b: *std.Build,
    modules: JuceModuleMap,
) []const []const u8 {
    var defs: std.ArrayList([]const u8) = .empty;
    var names = modules.keyIterator();
    while (names.next()) |name| {
        defs.append(b.allocator, b.fmt("-DJUCE_MODULE_AVAILABLE_{s}=1", .{name.*})) catch @panic("OOM");
    }
    return defs.toOwnedSlice(b.allocator) catch @panic("OOM");
}

pub fn addFlagsToLinkObjects(m: *std.Build.Module, flags: []const []const u8) void {
    const b = m.owner;
    for (m.link_objects.items) |lobj| {
        switch (lobj) {
            .c_source_file => updateFlags(std.Build.Module.CSourceFile, b, lobj.c_source_file, flags),
            .c_source_files => updateFlags(std.Build.Module.CSourceFiles, b, lobj.c_source_files, flags),
            else => {},
        }
    }
}

fn updateFlags(T: type, b: *std.Build, c_source_file: *T, flags: []const []const u8) void {
    if (T != std.Build.Module.CSourceFile and T != std.Build.Module.CSourceFiles) {
        @compileError("Needs to be CSourceFile or CSourceFiles");
    }
    const combined = std.mem.concat(b.allocator, []const u8, &.{
        c_source_file.flags,
        flags,
    }) catch @panic("OOM");
    c_source_file.flags = combined;
}
