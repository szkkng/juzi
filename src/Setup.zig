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

juzi_dep: *std.Build.Dependency,
root_module: *std.Build.Module,
juce_macros: std.ArrayList([]const u8),
binary_data: std.ArrayList(BinaryData.CreateOptions),

pub fn init(juzi_dep: *std.Build.Dependency, root_module: *std.Build.Module) Setup {
    const upstream = juzi_dep.builder.dependency("upstream", .{});
    root_module.addIncludePath(upstream.path("modules"));

    return Setup{
        .root_module = root_module,
        .juzi_dep = juzi_dep,
        .juce_macros = .empty,
        .binary_data = .empty,
    };
}

pub const AddOptions = struct {
    juce_modules: []const JuceModule,
    config: ProjectConfig,
};

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

pub const ConsoleApp = struct {
    artifact: *std.Build.Step.Compile,
    binary_data: ?*std.Build.Step.Compile = null,
};

pub fn addConsoleApp(
    self: Setup,
    options: AddOptions,
) ConsoleApp {
    const b = self.root_module.owner;
    const target = self.root_module.resolved_target.?;
    const optimize = self.root_module.optimize orelse .Debug;
    const upstream = self.juzi_dep.builder.dependency("upstream", .{});
    var binary_data: ?*std.Build.Step.Compile = null;

    var extra_flags = std.ArrayList([]const u8).empty;
    extra_flags.appendSlice(b.allocator, self.juce_macros.items) catch @panic("OOM");
    extra_flags.append(b.allocator, "-DJUCE_STANDALONE_APPLICATION=1") catch @panic("OOM");

    const juce_modules = resolveJuceModules(b, options.juce_modules);
    const required_flags = resolveJuceRequiredFlags(
        b,
        target,
        optimize,
        juce_modules,
        self.root_module.c_macros.items,
        extra_flags.items,
    );
    addJuceModules(self.root_module, juce_modules, .{
        .builder = b,
        .juce = upstream,
        .target = target,
        .optimize = optimize,
        .juce_required_flags = required_flags,
    });

    const juceaide = Juceaide.create(b, self.juzi_dep, target);

    const console_app = b.addExecutable(.{
        .name = options.config.product_name,
        .root_module = self.root_module,
    });
    linkOptionalLibraries(console_app.root_module, options.config);
    addFlagsToLinkObjects(console_app.root_module, required_flags.cxx);

    if (self.binary_data.items.len > 0) {
        for (self.binary_data.items) |opts| {
            const binary_data_lib = BinaryData.create(juceaide, target, optimize, opts);
            for (binary_data_lib.root_module.include_dirs.items) |include_dir| {
                self.root_module.addIncludePath(include_dir.path);
            }
            binary_data = binary_data_lib;
            console_app.root_module.linkLibrary(binary_data_lib);
        }
    }

    if (target.result.os.tag.isDarwin()) {
        darwin.sdk.addPaths(b, console_app.root_module);
    }

    return .{
        .artifact = console_app,
        .binary_data = binary_data,
    };
}

pub const GuiApp = struct {
    artifact: *std.Build.Step.Compile,
    install_step: *std.Build.Step,
    binary_data: ?*std.Build.Step.Compile = null,
};

pub fn addGuiApp(
    self: Setup,
    options: AddOptions,
) GuiApp {
    const b = self.root_module.owner;
    const target = self.root_module.resolved_target.?;
    const optimize = self.root_module.optimize orelse .Debug;
    const upstream = self.juzi_dep.builder.dependency("upstream", .{});
    var artifact: ?*std.Build.Step.Compile = null;
    var install_step: ?*std.Build.Step = null;
    var binary_data: ?*std.Build.Step.Compile = null;

    var extra_flags = std.ArrayList([]const u8).empty;
    extra_flags.appendSlice(b.allocator, self.juce_macros.items) catch @panic("OOM");
    extra_flags.append(b.allocator, "-DJUCE_STANDALONE_APPLICATION=1") catch @panic("OOM");

    const juce_modules = resolveJuceModules(b, options.juce_modules);
    const required_flags = resolveJuceRequiredFlags(
        b,
        target,
        optimize,
        juce_modules,
        self.root_module.c_macros.items,
        extra_flags.items,
    );
    addJuceModules(self.root_module, juce_modules, .{
        .builder = b,
        .juce = upstream,
        .target = target,
        .optimize = optimize,
        .juce_required_flags = required_flags,
    });

    const juceaide = Juceaide.create(b, self.juzi_dep, target);

    const product_name = options.config.product_name;
    const gui_app = b.addExecutable(.{
        .name = product_name,
        .root_module = self.root_module,
    });
    linkOptionalLibraries(gui_app.root_module, options.config);
    addFlagsToLinkObjects(gui_app.root_module, required_flags.cxx);

    if (self.binary_data.items.len > 0) {
        for (self.binary_data.items) |opts| {
            const binary_data_lib = BinaryData.create(juceaide, target, optimize, opts);
            for (binary_data_lib.root_module.include_dirs.items) |include_dir| {
                self.root_module.addIncludePath(include_dir.path);
            }
            binary_data = binary_data_lib;
            gui_app.root_module.linkLibrary(binary_data_lib);
        }
    }

    if (target.result.os.tag.isDarwin()) {
        darwin.sdk.addPaths(b, gui_app.root_module);
    }

    switch (target.result.os.tag) {
        .macos => {
            const install_gui_app = darwin.bundle.addInstallBundle(gui_app, .gui_app);

            const install_plist = darwin.bundle.addInstallInfoPlist(juceaide, options.config, .gui_app);
            install_gui_app.step.dependOn(&install_plist.step);

            const install_pkginfo = darwin.bundle.addInstallPkgInfo(juceaide, product_name, .gui_app);
            install_gui_app.step.dependOn(&install_pkginfo.step);

            const app_bundle_step = darwin.bundle.addInstallNib(b, upstream, product_name, .gui_app);
            install_gui_app.step.dependOn(&app_bundle_step.step);

            artifact = install_gui_app.artifact;
            install_step = &install_gui_app.step;
        },
        .linux => {
            const install_gui_app = b.addInstallArtifact(gui_app, .{});
            install_step = &install_gui_app.step;
        },
        // .windows => {
        // },
        else => @panic("Not implemented yet: only macOS is supported"),
    }

    return .{
        .artifact = gui_app,
        .install_step = install_step.?,
        .binary_data = binary_data,
    };
}

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
    const upstream = self.juzi_dep.builder.dependency("upstream", .{});
    var result: Plugin = .{
        .artifacts = .empty,
        .install_steps = .empty,
    };

    var extra_flags = std.ArrayList([]const u8).empty;
    extra_flags.appendSlice(b.allocator, self.juce_macros.items) catch @panic("OOM");
    const plugin_macros = PluginMacros.getPluginMacros(b, options.config) catch @panic("OOM");
    extra_flags.appendSlice(b.allocator, plugin_macros) catch @panic("OOM");

    const juce_modules = resolveJuceModules(b, options.juce_modules);
    const required_flags = resolveJuceRequiredFlags(
        b,
        target,
        optimize,
        juce_modules,
        self.root_module.c_macros.items,
        extra_flags.items,
    );
    addJuceModules(self.root_module, juce_modules, .{
        .builder = b,
        .juce = upstream,
        .target = target,
        .optimize = optimize,
        .juce_required_flags = required_flags,
    });

    const juceaide = Juceaide.create(b, self.juzi_dep, target);

    const plugin_shared_lib = b.addLibrary(.{
        .name = "plugin_shared_lib",
        .root_module = self.root_module,
    });
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
        darwin.sdk.addPaths(b, plugin_shared_lib.root_module);
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
                vst3_module.addIncludePath(upstream.path("modules"));
                vst3_module.addIncludePath(upstream.path("modules/juce_audio_processors_headless/format_types"));
                vst3_module.addIncludePath(upstream.path("modules/juce_audio_processors_headless/format_types/VST3_SDK"));

                const is_darwin = target.result.os.tag.isDarwin();
                vst3_module.addCSourceFiles(.{
                    .root = upstream.path("modules"),
                    .files = &.{b.fmt(
                        "juce_audio_plugin_client/juce_audio_plugin_client_VST3.{s}",
                        .{if (is_darwin) "mm" else "cpp"},
                    )},
                    .flags = flags.items,
                });
                if (target.result.os.tag.isDarwin()) {
                    darwin.sdk.addPaths(b, vst3_module);
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
                        const install_vst3 = darwin.bundle.addInstallBundle(vst3, .{ .plugin = .vst3 });
                        const adhoc_sign_run = darwin.codesign.addAdhocCodeSign(
                            b,
                            b.getInstallPath(.prefix, b.fmt("{s}.vst3", .{vst3.name})),
                        );
                        adhoc_sign_run.step.dependOn(&install_vst3.step);
                        vst3_step.dependOn(&adhoc_sign_run.step);

                        const install_plist = darwin.bundle.addInstallInfoPlist(juceaide, config, .{ .plugin = .vst3 });
                        const install_pkginfo = darwin.bundle.addInstallPkgInfo(juceaide, vst3.name, .{ .plugin = .vst3 });
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
                        upstream,
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
                au_module.addIncludePath(upstream.path("modules"));
                au_module.addIncludePath(upstream.path("modules/juce_audio_plugin_client/AU"));
                au_module.addCSourceFiles(.{
                    .root = upstream.path("modules"),
                    .files = &.{
                        "juce_audio_plugin_client/juce_audio_plugin_client_AU_1.mm",
                        "juce_audio_plugin_client/juce_audio_plugin_client_AU_2.mm",
                    },
                    .flags = flags.items,
                });
                if (target.result.os.tag.isDarwin()) {
                    darwin.sdk.addPaths(b, au_module);
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

                const install_au = darwin.bundle.addInstallBundle(au, .{ .plugin = .au });
                const adhoc_sign_run = darwin.codesign.addAdhocCodeSign(
                    b,
                    b.getInstallPath(.prefix, b.fmt("{s}.component", .{au.name})),
                );
                adhoc_sign_run.step.dependOn(&install_au.step);
                au_step.dependOn(&adhoc_sign_run.step);

                const install_plist = darwin.bundle.addInstallInfoPlist(juceaide, config, .{ .plugin = .au });
                const install_pkginfo = darwin.bundle.addInstallPkgInfo(juceaide, au.name, .{ .plugin = .au });
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
                standalone_module.addIncludePath(upstream.path("modules"));
                standalone_module.addCSourceFiles(.{
                    .root = upstream.path("modules"),
                    .files = &.{
                        "juce_audio_plugin_client/juce_audio_plugin_client_Standalone.cpp",
                    },
                    .flags = flags.items,
                });
                if (target.result.os.tag.isDarwin()) {
                    darwin.sdk.addPaths(b, standalone_module);
                }

                const standalone = b.addExecutable(.{
                    .name = config.product_name,
                    .root_module = standalone_module,
                });
                standalone.root_module.linkLibrary(plugin_shared_lib);

                const standalone_step = b.step("standalone", "Build standalone");

                switch (target.result.os.tag) {
                    .macos => {
                        const install_standalone = darwin.bundle.addInstallBundle(standalone, .{ .plugin = .standalone });
                        const install_plist = darwin.bundle.addInstallInfoPlist(juceaide, options.config, .{ .plugin = .standalone });
                        const install_pkginfo = darwin.bundle.addInstallPkgInfo(juceaide, config.product_name, .{ .plugin = .standalone });
                        const install_nib = darwin.bundle.addInstallNib(b, upstream, config.product_name, .{ .plugin = .standalone });

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

pub fn getJuceCommonFlags(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) []const []const u8 {
    var flags = std.ArrayList([]const u8).empty;

    switch (target.result.os.tag) {
        .macos => {
            flags.append(b.allocator, "-DJUCE_MAC=1") catch @panic("OOM");
        },
        .linux => {
            flags.append(b.allocator, "-DJUCE_LINUX=1") catch @panic("OOM");
        },
        // .windows => {
        //     flags.append(b.allocator, "-D_CONSOLE=1") catch @panic("OOM");
        // },
        else => @panic("Not implemented yet: only macOS is supported"),
    }

    const standard_defs = getJuceStandardDefs(b, optimize);
    for (standard_defs) |def| {
        flags.append(b.allocator, def) catch @panic("OOM");
    }

    flags.append(b.allocator, "-fvisibility=hidden") catch @panic("OOM");
    return flags.toOwnedSlice(b.allocator) catch @panic("OOM");
}

pub fn resolveJuceRequiredFlags(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    modules: JuceModuleMap,
    root_macros: []const []const u8,
    extra_flags: []const []const u8,
) JuceModule.RequiredFlags {
    var common = std.ArrayList([]const u8).empty;
    common.appendSlice(b.allocator, getJuceCommonFlags(b, target, optimize)) catch @panic("OOM");
    common.appendSlice(b.allocator, root_macros) catch @panic("OOM");
    common.appendSlice(b.allocator, extra_flags) catch @panic("OOM");
    common.appendSlice(b.allocator, getJuceModuleAvailableDefs(b, modules)) catch @panic("OOM");

    const c_flags = common.toOwnedSlice(b.allocator) catch @panic("OOM");

    var cxx = std.ArrayList([]const u8).empty;
    cxx.appendSlice(b.allocator, c_flags) catch @panic("OOM");
    cxx.append(b.allocator, "--std=c++20") catch @panic("OOM");
    cxx.append(b.allocator, "-fvisibility-inlines-hidden") catch @panic("OOM");

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

fn getJuceStandardDefs(
    b: *std.Build,
    optimize: std.builtin.OptimizeMode,
) []const []const u8 {
    var flags: std.ArrayList([]const u8) = .empty;

    flags.append(b.allocator, "-DJUCE_GLOBAL_MODULE_SETTINGS_INCLUDED=1") catch @panic("OOM");

    if (optimize == .Debug) {
        flags.append(b.allocator, "-DDEBUG=1") catch @panic("OOM");
        flags.append(b.allocator, "-D_DEBUG=1") catch @panic("OOM");
    } else {
        flags.append(b.allocator, "-DNDEBUG=1") catch @panic("OOM");
        flags.append(b.allocator, "-D_NDEBUG=1") catch @panic("OOM");
    }

    return flags.toOwnedSlice(b.allocator) catch @panic("OOM");
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
