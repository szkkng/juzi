const std = @import("std");
const Setup = @This();
pub const JuceModule = @import("root.zig").JuceModule;

// TODO: support more plugin formats
pub const PluginFormat = enum {
    vst3,
    standalone,
    // vst,
    // au,
    // auv3,
    // aax,
    // lv2,
    // unity,

    pub fn internalIdentifier(self: PluginFormat) []const u8 {
        return switch (self) {
            .vst3 => "VST3",
            .standalone => "Standalone Plugin",
            // .vst => "VST",
            // .au => "AU",
            // .auv3 => "AUv3 AppExtension",
            // .aax => "AAX",
            // .lv2 => "LV2",
            // .unity => "Unity Plugin",
        };
    }
};

// TODO: add more fields
// https://github.com/juce-framework/JUCE/blob/master/docs/CMake%20API.md#juce_add_target
pub const ProjectConfig = struct {
    product_name: []const u8,
    version: []const u8,
    build_version: ?[]const u8 = null,
    plugin_name: ?[]const u8 = null,
    company_name: []const u8 = "yourcompany",
    company_website: []const u8 = "",
    company_email: []const u8 = "",
    bundle_id: []const u8 = "com.yourcompany.product",
    plugin_manufacturer_code: []const u8 = "Manu",
    plugin_code: []const u8 = "Jzbs",
    formats: []const PluginFormat = &.{},
    // copy_plugin_after_build: ?bool = false,
    is_synth: bool = false,
    is_midi_effect: bool = false,
    editor_wants_keyboard_focus: bool = false,
    vst3_auto_manifest: bool = true,
};

juzi_dep: *std.Build.Dependency,
root_module: *std.Build.Module,
binary_data: std.ArrayList([]const u8),
juce_macros: std.ArrayList([]const u8),

pub fn init(juzi_dep: *std.Build.Dependency, root_module: *std.Build.Module) Setup {
    const upstream = juzi_dep.builder.dependency("upstream", .{});
    root_module.addIncludePath(upstream.path("modules"));

    return Setup{
        .root_module = root_module,
        .juzi_dep = juzi_dep,
        .binary_data = .empty,
        .juce_macros = .empty,
    };
}

pub const AddOptions = struct {
    juce_modules: []const JuceModule,
    config: ProjectConfig,
    flags: []const []const u8 = &.{},
};

pub fn addConsoleApp(
    self: Setup,
    options: AddOptions,
) *std.Build.Step.Compile {
    const b = self.root_module.owner;
    const target = self.root_module.resolved_target.?;
    const optimize = self.root_module.optimize orelse .Debug;

    switch (target.result.os.tag) {
        .macos => {
            addAppleSdkPaths(b, self.root_module);
        },
        // .windows => {
        // },
        else => @panic("Not implemented yet: only macOS is supported"),
    }

    var flags = std.ArrayList([]const u8).empty;

    for (getJuceCommonFlags(b, target, optimize)) |flag| {
        flags.append(b.allocator, flag) catch @panic("OOM");
    }
    for (options.flags) |flag| {
        flags.append(b.allocator, flag) catch @panic("OOM");
    }
    for (self.juce_macros.items) |macro| {
        flags.append(b.allocator, macro) catch @panic("OOM");
    }
    flags.append(b.allocator, "-DJUCE_STANDALONE_APPLICATION=1") catch @panic("OOM");

    const juce_modules_lib = addJuceModules(b, self.juzi_dep, .{
        .target = target,
        .optimize = optimize,
        .juce_modules = options.juce_modules,
    });
    for (getJuceModuleAvailableDefs(juce_modules_lib.root_module)) |flag| {
        flags.append(b.allocator, flag) catch @panic("OOM");
    }
    propagateFlagsToJuceModules(juce_modules_lib.root_module, flags.items);

    const console_app = b.addExecutable(.{
        .name = options.config.product_name,
        .root_module = self.root_module,
    });
    console_app.root_module.linkLibrary(juce_modules_lib);
    addFlagsToLinkObjects(console_app.root_module, flags.items);

    return console_app;
}

pub fn addGuiApp(
    self: Setup,
    options: AddOptions,
) *std.Build.Step.InstallArtifact {
    const b = self.root_module.owner;
    const target = self.root_module.resolved_target.?;
    const optimize = self.root_module.optimize orelse .Debug;
    const upstream = self.juzi_dep.builder.dependency("upstream", .{});

    switch (target.result.os.tag) {
        .macos => {
            addAppleSdkPaths(b, self.root_module);
        },
        // .windows => {
        // },
        else => @panic("Not implemented yet: only macOS is supported"),
    }

    var flags = std.ArrayList([]const u8).empty;

    for (getJuceCommonFlags(b, target, optimize)) |flag| {
        flags.append(b.allocator, flag) catch @panic("OOM");
    }
    for (options.flags) |flag| {
        flags.append(b.allocator, flag) catch @panic("OOM");
    }
    for (self.juce_macros.items) |macro| {
        flags.append(b.allocator, macro) catch @panic("OOM");
    }
    flags.append(b.allocator, "-DJUCE_STANDALONE_APPLICATION=1") catch @panic("OOM");

    var juce_modules: std.ArrayList(JuceModule) = .empty;
    for (options.juce_modules) |module| {
        juce_modules.append(b.allocator, module) catch @panic("OOM");
    }
    juce_modules.append(b.allocator, .juce_build_tools) catch @panic("OOM");

    const juce_modules_lib = addJuceModules(b, self.juzi_dep, .{
        .target = target,
        .optimize = optimize,
        .juce_modules = juce_modules.items,
    });
    for (getJuceModuleAvailableDefs(juce_modules_lib.root_module)) |flag| {
        flags.append(b.allocator, flag) catch @panic("OOM");
    }
    propagateFlagsToJuceModules(juce_modules_lib.root_module, flags.items);

    const juceaide = addJuceaide(upstream, juce_modules_lib, target, optimize);
    addFlagsToLinkObjects(juceaide.root_module, flags.items);

    const product_name = options.config.product_name;
    const gui_app = b.addExecutable(.{
        .name = product_name,
        .root_module = self.root_module,
    });
    gui_app.root_module.linkLibrary(juce_modules_lib);
    addFlagsToLinkObjects(gui_app.root_module, flags.items);

    switch (target.result.os.tag) {
        .macos => {
            const install_gui_app = addInstallBundle(gui_app, .gui_app);

            const install_plist = addInstallInfoPlist(juceaide, options.config, .gui_app);
            install_gui_app.step.dependOn(&install_plist.step);

            const install_pkginfo = addInstallPkgInfo(juceaide, product_name, .gui_app);
            install_gui_app.step.dependOn(&install_pkginfo.step);

            const app_bundle_step = addInstallNib(b, upstream, product_name, .gui_app);
            install_gui_app.step.dependOn(&app_bundle_step.step);

            return install_gui_app;
        },
        // .windows => {
        // },
        else => @panic("Not implemented yet: only macOS is supported"),
    }
}

pub const Plugin = struct {
    artifacts: std.AutoHashMap(PluginFormat, *std.Build.Step.Compile),
    install_steps: std.AutoHashMap(PluginFormat, *std.Build.Step),
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
    var plugin: Plugin = .{
        .artifacts = .init(b.allocator),
        .install_steps = .init(b.allocator),
    };

    switch (target.result.os.tag) {
        .macos => {
            addAppleSdkPaths(b, self.root_module);
        },
        // .windows => {
        // },
        else => @panic("Not implemented yet: only macOS is supported"),
    }

    var flags = std.ArrayList([]const u8).empty;

    for (getJuceCommonFlags(b, target, optimize)) |flag| {
        flags.append(b.allocator, flag) catch @panic("OOM");
    }
    for (options.flags) |flag| {
        flags.append(b.allocator, flag) catch @panic("OOM");
    }
    for (self.juce_macros.items) |macro| {
        flags.append(b.allocator, macro) catch @panic("OOM");
    }

    const config = options.config;
    // TODO: add more JUCE plugin macros and clean up
    flags.append(b.allocator, b.fmt("-DJucePlugin_IsSynth={d}", .{@intFromBool(config.is_synth)})) catch @panic("OOM");
    flags.append(b.allocator, b.fmt("-DJucePlugin_IsMidiEffect={d}", .{@intFromBool(config.is_midi_effect)})) catch @panic("OOM");
    flags.append(b.allocator, b.fmt("-DJucePlugin_Manufacturer=\"{s}\"", .{config.company_name})) catch @panic("OOM");
    flags.append(b.allocator, b.fmt("-DJucePlugin_ManufacturerEmail=\"{s}\"", .{config.company_email})) catch @panic("OOM");
    flags.append(b.allocator, b.fmt("-DJucePlugin_ManufacturerWebsite=\"{s}\"", .{config.company_website})) catch @panic("OOM");
    flags.append(b.allocator, b.fmt("-DJucePlugin_ManufacturerCode=\'{s}\'", .{config.plugin_manufacturer_code})) catch @panic("OOM");
    flags.append(b.allocator, b.fmt("-DJucePlugin_PluginCode=\'{s}\'", .{config.plugin_code})) catch @panic("OOM");
    flags.append(b.allocator, b.fmt("-DJucePlugin_ProducesMidiOutput={d}", .{0})) catch @panic("OOM");
    flags.append(b.allocator, b.fmt("-DJucePlugin_EditorRequiresKeyboardFocus={d}", .{@intFromBool(config.editor_wants_keyboard_focus)})) catch @panic("OOM");
    flags.append(b.allocator, b.fmt("-DJucePlugin_VSTUniqueID={s}", .{"JucePlugin_PluginCode"})) catch @panic("OOM");
    flags.append(b.allocator, b.fmt("-DJucePlugin_Name=\"{s}\"", .{config.plugin_name orelse config.product_name})) catch @panic("OOM");
    flags.append(b.allocator, b.fmt("-DJuceProduct_Name=\"{s}\"", .{config.product_name})) catch @panic("OOM");
    flags.append(b.allocator, b.fmt("-DJucePlugin_WantsMidiInput={d}", .{0})) catch @panic("OOM");

    const versionCode = semanticVersionToVersionCode(b, config.version) catch @panic("invalid version");
    flags.append(b.allocator, b.fmt("-DJucePlugin_VersionCode={s}", .{versionCode})) catch @panic("OOM");
    flags.append(b.allocator, b.fmt("-DJucePlugin_Version={s}", .{config.version})) catch @panic("OOM");
    flags.append(b.allocator, b.fmt("-DJucePlugin_VersionString=\"{s}\"", .{config.version})) catch @panic("OOM");

    var juce_modules: std.ArrayList(JuceModule) = .empty;
    for (options.juce_modules) |module| {
        juce_modules.append(b.allocator, module) catch @panic("OOM");
    }
    juce_modules.append(b.allocator, .juce_build_tools) catch @panic("OOM");

    const juce_modules_lib = addJuceModules(b, self.juzi_dep, .{
        .target = target,
        .optimize = optimize,
        .juce_modules = juce_modules.items,
    });
    for (getJuceModuleAvailableDefs(juce_modules_lib.root_module)) |flag| {
        flags.append(b.allocator, flag) catch @panic("OOM");
    }
    propagateFlagsToJuceModules(juce_modules_lib.root_module, flags.items);

    const juceaide = addJuceaide(upstream, juce_modules_lib, target, optimize);
    addFlagsToLinkObjects(juceaide.root_module, flags.items);

    const plugin_shared_lib = b.addLibrary(.{
        .name = "plugin_shared_lib",
        .root_module = self.root_module,
    });
    plugin_shared_lib.linkLibrary(juce_modules_lib);
    addFlagsToLinkObjects(plugin_shared_lib.root_module, flags.items);

    if (self.binary_data.items.len > 0) {
        const binary_data_lib = addBinaryData(b, .{
            .target = target,
            .optimize = optimize,
            .juceaide = juceaide,
            .binary_data = self.binary_data.items,
        });
        for (binary_data_lib.root_module.include_dirs.items) |include_dir| {
            self.root_module.addIncludePath(include_dir.path);
        }
        plugin.binary_data = binary_data_lib;
        plugin_shared_lib.linkLibrary(binary_data_lib);
    }

    for (config.formats) |format| {
        switch (format) {
            .vst3 => {
                flags.append(b.allocator, "-DJucePlugin_Build_VST3=1") catch @panic("OOM");
                const vst3_module = b.createModule(.{
                    .target = target,
                    .optimize = optimize,
                    .link_libcpp = true,
                });
                vst3_module.addIncludePath(upstream.path("modules"));
                vst3_module.addIncludePath(upstream.path("modules/juce_audio_processors/format_types/VST3_SDK"));
                vst3_module.addCSourceFiles(.{
                    .root = upstream.path("modules"),
                    .files = &.{
                        "juce_audio_plugin_client/juce_audio_plugin_client_VST3.mm",
                    },
                    .flags = flags.items,
                });

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
                vst3.linkLibrary(plugin_shared_lib);

                const install_vst3 = addInstallBundle(vst3, .{ .plugin = .vst3 });
                const adhoc_sign_run = addAdhocCodeSign(
                    b,
                    b.getInstallPath(.prefix, b.fmt("{s}.vst3", .{vst3.name})),
                );
                adhoc_sign_run.step.dependOn(&install_vst3.step);
                vst3_step.dependOn(&adhoc_sign_run.step);

                const install_plist = addInstallInfoPlist(juceaide, config, .{ .plugin = .vst3 });
                const install_pkginfo = addInstallPkgInfo(juceaide, vst3.name, .{ .plugin = .vst3 });
                vst3_step.dependOn(&install_plist.step);
                vst3_step.dependOn(&install_pkginfo.step);

                if (config.vst3_auto_manifest) {
                    const install_module_info = addInstallModuleInfo(
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

                plugin.artifacts.put(.vst3, vst3) catch @panic("OOM");
                plugin.install_steps.put(.vst3, vst3_step) catch @panic("OOM");
            },
            .standalone => {
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

                const standalone = b.addExecutable(.{
                    .name = config.product_name,
                    .root_module = standalone_module,
                });
                standalone.linkLibrary(plugin_shared_lib);

                const standalone_step = b.step("standalone", "Build standalone");

                const install_standalone = addInstallBundle(standalone, .{ .plugin = .standalone });
                const install_plist = addInstallInfoPlist(juceaide, options.config, .{ .plugin = .standalone });
                const install_pkginfo = addInstallPkgInfo(juceaide, config.product_name, .{ .plugin = .standalone });
                const install_nib = addInstallNib(b, upstream, config.product_name, .{ .plugin = .standalone });

                standalone_step.dependOn(&install_standalone.step);
                standalone.step.dependOn(&install_plist.step);
                standalone_step.dependOn(&install_pkginfo.step);
                standalone_step.dependOn(&install_nib.step);

                const run_cmd = b.addRunArtifact(standalone);
                run_cmd.step.dependOn(standalone_step);
                const run_step = b.step("run", "Run standalone");
                run_step.dependOn(&run_cmd.step);

                plugin.artifacts.put(.standalone, standalone) catch @panic("OOM");
                plugin.install_steps.put(.standalone, standalone_step) catch @panic("OOM");
            },
            // else => @panic("Not implemented yet"),
        }
    }

    return plugin;
}

// Similar to `std.Build.Module.addCMacro`, but for defining
// JUCE_* macros that apply to all JUCE-related compilation,
// not just the root module.
pub fn addJuceMacro(self: *Setup, name: []const u8, value: []const u8) void {
    const b = self.root_module.owner;
    self.juce_macros.append(b.allocator, b.fmt("-D{s}={s}", .{ name, value })) catch @panic("OOM");
}

fn getJuceCommonFlags(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) []const []const u8 {
    var flags = std.ArrayList([]const u8).empty;

    switch (target.result.os.tag) {
        .macos => {
            flags.append(b.allocator, "-DJUCE_MAC=1") catch @panic("OOM");
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
    flags.append(b.allocator, "-fvisibility-inlines-hidden") catch @panic("OOM");

    // Zig enforces -Werror=date-time in release builds for reproducible builds,
    // but juce_core_CompilationTime.cpp uses __DATE__/__TIME__.
    // Disable this error as a workaround to allow JUCE to build.
    // https://github.com/ziglang/zig/pull/20821/commits/ff7bdbbd7d997b22f50704c5268839bea9321088
    flags.append(b.allocator, "-Wno-error=date-time") catch @panic("OOM");

    return flags.toOwnedSlice(b.allocator) catch @panic("OOM");
}

const AddBinaryDataOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    juceaide: *std.Build.Step.Compile,
    binary_data: []const []const u8,
};

fn addBinaryData(
    b: *std.Build,
    options: AddBinaryDataOptions,
) *std.Build.Step.Compile {
    const binary_data_lib = b.addLibrary(.{
        .name = "binary_data",
        .root_module = b.createModule(.{
            .target = options.target,
            .optimize = options.optimize,
            .link_libcpp = true,
        }),
    });

    const binary_data = options.binary_data;
    const input_list_file = addInputFileList(b, binary_data);

    var binary_data_files: std.ArrayList([]const u8) = .empty;
    for (binary_data, 0..) |file, i| {
        _ = file;
        binary_data_files.append(b.allocator, b.fmt("{s}{d}.cpp", .{ "BinaryData", i + 1 })) catch @panic("OOM");
    }

    const output_dir = input_list_file.dirname();
    const binary_data_cmd = b.addRunArtifact(options.juceaide);
    binary_data_cmd.setCwd(output_dir);

    binary_data_cmd.addArgs(&.{
        "binarydata",
        "BinaryData",
        "BinaryData.h",
    });
    // The fourth juceaide argument (the BinaryData output directory) is currently
    // passed as a relative path, which triggers the assertion
    // “JUCE Assertion failure in juce_File.cpp:219”. The build still works, so
    // the output is suppressed here just to keep the logs clean.
    // Is there a good way to provide an absolute path instead?
    binary_data_cmd.addDirectoryArg(output_dir);
    binary_data_cmd.addFileArg(input_list_file);
    _ = binary_data_cmd.captureStdErr();

    binary_data_lib.root_module.addCSourceFiles(.{
        .root = output_dir,
        .files = binary_data_files.items,
    });
    binary_data_lib.root_module.addIncludePath(output_dir);
    binary_data_lib.step.dependOn(&binary_data_cmd.step);

    return binary_data_lib;
}

fn addInputFileList(
    b: *std.Build,
    input_files: []const []const u8,
) std.Build.LazyPath {
    const wf = b.addWriteFiles();
    const input_file_name = "input_file_list";

    for (input_files) |file| {
        _ = wf.addCopyFile(b.path(file), file);
    }

    const path = wf.add(input_file_name, std.mem.join(b.allocator, "\n", input_files) catch @panic("OOM"));
    return path;
}

fn addAdhocCodeSign(
    b: *std.Build,
    artifact_path: []const u8,
) *std.Build.Step.Run {
    const adhoc_sign_cmd = b.addSystemCommand(&.{
        "codesign",
        "--sign",
        "-",
        "--force",
        artifact_path,
    });
    adhoc_sign_cmd.has_side_effects = true;
    _ = adhoc_sign_cmd.captureStdErr();
    return adhoc_sign_cmd;
}

const AddInstallModuleInfoOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    flags: []const []const u8 = &.{},
};

// Creates the install step for generating and installing the VST3 moduleinfo.json file.
fn addInstallModuleInfo(
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
    manifest_helper.root_module.addIncludePath(upstream.path("modules/juce_audio_processors/format_types/VST3_SDK"));
    manifest_helper.root_module.addCSourceFiles(.{
        .root = upstream.path("modules/juce_audio_plugin_client/VST3"),
        .files = &.{"juce_VST3ManifestHelper.mm"},
        .flags = options.flags,
    });
    manifest_helper.root_module.linkFramework("Foundation", .{});

    const manifest_helper_cmd = b.addRunArtifact(manifest_helper);
    const out_module_info = manifest_helper_cmd.captureStdOut();
    const install_module_info = b.addInstallFileWithDir(
        out_module_info,
        .prefix,
        b.fmt("{s}.vst3/Contents/Resources/moduleinfo.json", .{product_name}),
    );

    return install_module_info;
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

// Recursively collect all JUCE modules imported by the root module,
// inserting them into the result map without duplicates.
fn collectJuceModules(
    m: *std.Build.Module,
    visited: *std.AutoHashMap(*std.Build.Module, void),
    result: *std.StringHashMap(*std.Build.Module),
) void {
    if (visited.contains(m)) return;

    visited.put(m, {}) catch @panic("OOM");
    const keys = m.import_table.keys();
    const vals = m.import_table.values();

    for (keys, vals) |name, val| {
        if (std.mem.startsWith(u8, name, "juce_")) {
            if (!result.contains(name)) {
                result.put(name, val) catch @panic("OOM");
            }
        }
        collectJuceModules(val, visited, result);
    }
}

const AddJuceModulesOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    juce_modules: []const JuceModule,
};

fn addJuceModules(
    b: *std.Build,
    juzi_dep: *std.Build.Dependency,
    options: AddJuceModulesOptions,
) *std.Build.Step.Compile {
    const juce_modules_lib = b.addLibrary(.{
        .name = "juce_modules",
        .root_module = b.createModule(.{
            .target = options.target,
            .optimize = options.optimize,
            .link_libcpp = true,
        }),
    });
    for (options.juce_modules) |module| {
        juce_modules_lib.root_module.addImport(@tagName(module), juzi_dep.module(@tagName(module)));
    }

    return juce_modules_lib;
}

// Describes the final product kind (app or plugin) and, if a plugin, its format.
const ProductKind = union(enum) {
    console_app,
    gui_app,
    plugin: PluginFormat,

    pub fn juceaideIdentifier(self: ProductKind) []const u8 {
        return switch (self) {
            .console_app => "ConsoleApp",
            .gui_app => "App",
            .plugin => self.plugin.internalIdentifier(),
        };
    }
    pub fn bundleTypeIdentifier(self: ProductKind) []const u8 {
        return switch (self) {
            .console_app, .gui_app => "app",
            .plugin => |fmt| switch (fmt) {
                .vst3 => "vst3",
                .standalone => "app",
                // .au => "component",
            },
        };
    }
};

fn addJuceaide(
    upstream: *std.Build.Dependency,
    juce_modules_lib: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const b = juce_modules_lib.step.owner;
    const juceaide = b.addExecutable(.{
        .name = "juceaide",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
    });
    juceaide.root_module.linkLibrary(juce_modules_lib);
    juceaide.root_module.addIncludePath(upstream.path("modules"));
    juceaide.root_module.addIncludePath(upstream.path("extras/Build"));
    juceaide.root_module.addCSourceFiles(.{
        .root = upstream.path("extras/Build/juceaide"),
        .files = &.{"Main.cpp"},
    });

    return juceaide;
}

// Creates the install step for placing the artifact in a macOS bundle structure.
fn addInstallBundle(
    artifact: *std.Build.Step.Compile,
    kind: ProductKind,
) *std.Build.Step.InstallArtifact {
    const b = artifact.step.owner;
    const bundle_subpath = b.fmt("{s}.{s}/Contents/MacOS", .{ artifact.name, kind.bundleTypeIdentifier() });
    const install_gui_app = b.addInstallArtifact(artifact, .{
        .dest_dir = .{ .override = .{ .custom = bundle_subpath } },
        .dest_sub_path = artifact.name,
    });
    return install_gui_app;
}

// Creates the install step for generating and installing the bundle's Info.plist.
fn addInstallInfoPlist(
    juceaide: *std.Build.Step.Compile,
    config: ProjectConfig,
    kind: ProductKind,
) *std.Build.Step.InstallFile {
    const b = juceaide.step.owner;
    const plist_cmd = b.addRunArtifact(juceaide);
    const input_info_file = generateInfoText(b, config) catch @panic("Failed to generate Info.txt");
    plist_cmd.setCwd(input_info_file);
    plist_cmd.addArgs(&.{
        "plist",
        kind.juceaideIdentifier(),
        "Info.txt",
    });
    const out_info_plist = plist_cmd.addOutputFileArg("Info.plist");
    const install_plist = b.addInstallFileWithDir(
        out_info_plist,
        .prefix,
        b.fmt(
            "{s}.{s}/Contents/Info.plist",
            .{ config.product_name, kind.bundleTypeIdentifier() },
        ),
    );
    // Suppress the "JUCE vX.X.X" banner to keep the build logs clean.
    _ = plist_cmd.captureStdErr();

    return install_plist;
}

fn appendRecord(buf: *std.ArrayList(u8), gpa: std.mem.Allocator, key: []const u8, value: []const u8) !void {
    const rs: u8 = 30; // Record Separator
    const us: u8 = 31; // Unit Separator

    try buf.appendSlice(gpa, key);
    try buf.append(gpa, us);
    try buf.appendSlice(gpa, value);
    try buf.append(gpa, rs);
}

fn generateInfoText(b: *std.Build, config: ProjectConfig) !std.Build.LazyPath {
    var buf: std.ArrayList(u8) = .empty;

    try appendRecord(&buf, b.allocator, "EXECUTABLE_NAME", config.product_name);
    try appendRecord(&buf, b.allocator, "VERSION", config.version);
    try appendRecord(&buf, b.allocator, "BUILD_VERSION", (config.build_version orelse config.version));
    try appendRecord(&buf, b.allocator, "BUNDLE_ID", config.bundle_id);

    // TODO: append more records
    // ...

    const wf = b.addWriteFiles();
    _ = wf.add("Info.txt", buf.items);

    return wf.getDirectory();
}

// Creates the install step for generating and installing the bundle's PkgInfo file.
fn addInstallPkgInfo(
    juceaide: *std.Build.Step.Compile,
    product_name: []const u8,
    kind: ProductKind,
) *std.Build.Step.InstallFile {
    const b = juceaide.step.owner;
    const pkginfo_cmd = b.addRunArtifact(juceaide);
    pkginfo_cmd.addArgs(&.{
        "pkginfo",
        kind.juceaideIdentifier(),
    });
    const out_pkginfo = pkginfo_cmd.addOutputFileArg("PkgInfo");
    const install_pkginfo = b.addInstallFileWithDir(
        out_pkginfo,
        .prefix,
        b.fmt(
            "{s}.{s}/Contents/PkgInfo",
            .{ product_name, kind.bundleTypeIdentifier() },
        ),
    );
    // Suppress the "JUCE vX.X.X" banner to keep the build logs clean.
    _ = pkginfo_cmd.captureStdErr();

    return install_pkginfo;
}

// Creates the install step for installing the .nib file. I don’t yet fully
// understand how this .nib file is used, and the installed result is not
// yet verified to work correctly.
fn addInstallNib(
    b: *std.Build,
    upstream: *std.Build.Dependency,
    product_name: []const u8,
    product_kind: ProductKind,
) *std.Build.Step.InstallFile {
    const wf = b.addWriteFiles();
    const nib_file_name = "RecentFilesMenuTemplate.nib";
    const nib_file_source = b.fmt("extras/Build/CMake/{s}", .{nib_file_name});
    const nib_file_path = wf.addCopyFile(upstream.path(nib_file_source), nib_file_name);
    const install_nib_file = b.addInstallFileWithDir(
        nib_file_path,
        .prefix,
        b.fmt("{s}.{s}/Contents/Resources/{s}", .{
            product_name,
            product_kind.bundleTypeIdentifier(),
            nib_file_name,
        }),
    );
    return install_nib_file;
}

fn getJuceModuleAvailableDefs(m: *std.Build.Module) []const []const u8 {
    const b = m.owner;
    var visited_mods = std.AutoHashMap(*std.Build.Module, void).init(b.allocator);
    var available_mods = std.StringHashMap(*std.Build.Module).init(b.allocator);
    collectJuceModules(m, &visited_mods, &available_mods);

    var juceModuleAvailableDefs: std.ArrayList([]const u8) = .empty;
    var key_it = available_mods.keyIterator();
    while (key_it.next()) |mod_name_ptr| {
        juceModuleAvailableDefs.append(b.allocator, b.fmt("-DJUCE_MODULE_AVAILABLE_{s}=1", .{mod_name_ptr.*})) catch @panic("OOM");
    }
    return juceModuleAvailableDefs.toOwnedSlice(b.allocator) catch @panic("OOM");
}

fn addFlagsToLinkObjects(m: *std.Build.Module, flags: []const []const u8) void {
    const b = m.owner;
    for (m.link_objects.items) |lobj| {
        switch (lobj) {
            .c_source_file => updateFlags(std.Build.Module.CSourceFile, b, lobj.c_source_file, flags),
            .c_source_files => updateFlags(std.Build.Module.CSourceFiles, b, lobj.c_source_files, flags),
            else => {},
        }
    }
}

// Propagate compile flags and this module’s macros to all imported JUCE modules.
fn propagateFlagsToJuceModules(root_module: *std.Build.Module, flags: []const []const u8) void {
    const b = root_module.owner;
    var visited_mods = std.AutoHashMap(*std.Build.Module, void).init(b.allocator);
    var available_mods = std.StringHashMap(*std.Build.Module).init(b.allocator);
    collectJuceModules(root_module, &visited_mods, &available_mods);

    var value_it = available_mods.valueIterator();
    while (value_it.next()) |juce_module_ptr| {
        const juce_module = juce_module_ptr.*;

        for (root_module.c_macros.items) |macro| {
            juce_module.c_macros.append(b.allocator, macro) catch @panic("OOM");
        }

        for (juce_module.link_objects.items) |lobj| {
            switch (lobj) {
                .c_source_file => updateFlags(std.Build.Module.CSourceFile, b, lobj.c_source_file, flags),
                .c_source_files => updateFlags(std.Build.Module.CSourceFiles, b, lobj.c_source_files, flags),
                else => {},
            }
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

fn semanticVersionToVersionCode(b: *std.Build, ver: []const u8) ![]const u8 {
    const version = try std.SemanticVersion.parse(ver);
    const v = (version.major << 16) | (version.minor << 8) | version.patch;
    return b.fmt("0x{X}", .{v});
}

fn addAppleSdkPaths(b: *std.Build, m: *std.Build.Module) void {
    const sdkPath = std.zig.system.darwin.getSdk(b.allocator, &m.resolved_target.?.result) orelse
        @panic("apple sdk not found");
    m.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ sdkPath, "/System/Library/Frameworks" }) });
    m.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdkPath, "/usr/include" }) });
    m.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdkPath, "/usr/lib" }) });
}
