const std = @import("std");
const Setup = @This();
const darwin = @import("darwin.zig");
const Juceaide = @import("Juceaide.zig");
const BinaryData = @import("BinaryData.zig");
const Vst3Manifest = @import("plugin/vst3_manifest.zig");
const PluginMacros = @import("plugin/macros.zig");

pub const PluginFormat = @import("plugin/format.zig").PluginFormat;
pub const Vst2Category = @import("plugin/category.zig").Vst2Category;
pub const Vst3Category = @import("plugin/category.zig").Vst3Category;
pub const JuceModule = @import("modules.zig").JuceModule;

// TODO: add more fields
// https://github.com/juce-framework/JUCE/blob/master/docs/CMake%20API.md#juce_add_target
pub const ProjectConfig = struct {
    product_name: []const u8,
    version: []const u8,
    build_version: []const u8,
    bundle_id: []const u8,

    microphone_permission_enabled: ?bool,
    microphone_permission_text: ?[]const u8,
    camera_permission_enabled: ?bool,
    camera_permission_text: ?[]const u8,
    bluetooth_permission_enabled: ?bool,
    bluetooth_permission_text: ?[]const u8,
    local_network_permission_enabled: ?bool,
    local_network_permission_text: ?[]const u8,
    send_apple_events_permission_enabled: ?bool,
    send_apple_events_permission_text: ?[]const u8,

    // file_sharing_enabled: ?bool,
    // document_browser_enabled: ?bool,
    // status_bar_hidden: ?bool,
    // requires_full_screen: ?bool,
    // background_audio_enabled: ?bool,
    // background_ble_enabled : ?bool,
    // app_groups_enabled: ?bool,
    // app_group_ids: ?[]const u8,
    // icloud_permissions_enabled: ?bool,
    // iphone_screen_orientations
    // ipad_screen_orientations
    // launch_storyboard_file
    // custom_xcassets_folder
    // targeted_device_family

    // icon_big: ?[]const u8,
    // icon_small: ?[]const u8,

    company_copyright: ?[]const u8,
    company_name: []const u8,
    company_website: []const u8,
    company_email: []const u8,

    document_extensions: []const []const u8,

    needs_curl: bool,
    needs_web_browser: bool,
    needs_webview2: bool,
    needs_store_kit: bool,

    // push_notifications_enabled: bool,
    // network_multicast_enabled: bool,
    // hardened_runtime_enabled: bool,
    // hardened_runtime_options: []const []const u8,
    // app_sandbox_enabled: bool,
    // app_sandbox_inherit: bool,
    // app_sandbox_options: []const []const u8,
    // app_sandbox_file_access_home_ro: []const []const u8,
    // app_sandbox_file_access_abs_ro: []const []const u8,
    // app_sandbox_file_access_abs_rw: []const []const u8,
    // app_sandbox_exception_iokit: []const []const u8,
    plist_to_merge: []const u8,

    formats: []const PluginFormat,
    plugin_name: []const u8,
    plugin_manufacturer_code: []const u8,

    plugin_code: []const u8,
    description: []const u8,
    is_synth: bool,
    needs_midi_input: bool,
    needs_midi_output: bool,
    is_midi_effect: bool,
    editor_wants_keyboard_focus: bool,

    // disable_aax_bypass
    // disable_aax_multi_mono
    // aax_identifier
    // lv2uri
    vst_num_midi_ins: u8,
    vst_num_midi_outs: u8,
    vst2_category: Vst2Category,
    vst3_categories: []const Vst3Category,

    // au_main_type
    // au_export_prefix
    // au_sandbox_safe
    // suppress_au_plist_resource_usage
    // aax_category
    // pluginhost_au

    use_legacy_compatibility_plugin_code: bool,

    // copy_plugin_after_build: bool = true,
    // vst_copy_dir
    // vst3_copy_dir
    // aax_copy_dir
    // au_copy_dir
    // unity_copy_dir

    // is_ara_effect
    // ara_factory_id
    // ara_document_archive_id
    // ara_analysis_types
    // ara_transformation_flags

    vst3_auto_manifest: bool,

    const CreateOptions = struct {
        product_name: []const u8,
        version: []const u8,
        build_version: ?[]const u8 = null,
        bundle_id: ?[]const u8 = null,
        microphone_permission_enabled: ?bool = null,
        microphone_permission_text: ?[]const u8 = null,
        camera_permission_enabled: ?bool = null,
        camera_permission_text: ?[]const u8 = null,
        bluetooth_permission_enabled: ?bool = null,
        bluetooth_permission_text: ?[]const u8 = null,
        local_network_permission_enabled: ?bool = null,
        local_network_permission_text: ?[]const u8 = null,
        send_apple_events_permission_enabled: ?bool = null,
        send_apple_events_permission_text: ?[]const u8 = null,
        // icon_big: ?[]const u8 = null,
        // icon_small: ?[]const u8 = null,
        company_copyright: ?[]const u8 = null,
        company_name: []const u8 = "yourcompany",
        company_website: []const u8 = "",
        company_email: []const u8 = "",
        document_extensions: []const []const u8 = &.{},
        needs_curl: bool = false,
        needs_web_browser: bool = false,
        needs_webview2: bool = false,
        needs_store_kit: bool = false,
        plist_to_merge: []const u8 = "",
        formats: []const PluginFormat = &.{},
        plugin_name: ?[]const u8 = null,
        plugin_manufacturer_code: []const u8 = "Manu",
        plugin_code: ?[]const u8 = null,
        description: ?[]const u8 = null,
        is_synth: bool = false,
        needs_midi_output: bool = false,
        needs_midi_input: bool = false,
        is_midi_effect: bool = false,
        editor_wants_keyboard_focus: bool = false,
        vst3_auto_manifest: bool = true,
        vst2_category: ?Vst2Category = null,
        vst3_categories: ?[]const Vst3Category = null,
        vst_num_midi_ins: u8 = 16,
        vst_num_midi_outs: u8 = 16,
        use_legacy_compatibility_plugin_code: bool = false,
    };

    pub fn create(b: *std.Build, options: CreateOptions) ProjectConfig {
        const bundle_id = options.bundle_id orelse b.fmt("com.{s}.{s}", .{ options.company_name, options.product_name });
        if (std.mem.containsAtLeast(u8, bundle_id, 1, " ")) {
            @panic(b.fmt("Invalid bundle identifier '{s}': cannot contain spaces", .{bundle_id}));
        }
        const manu_code = if (options.use_legacy_compatibility_plugin_code) "proj" else options.plugin_manufacturer_code;
        const manu_code_hex = b.fmt("0x{x}", .{manu_code});
        const plugin_code_hex = b.fmt("0x{x}", .{options.plugin_code orelse makeValid4cc(b)});
        const vst2_category = options.vst2_category orelse Vst2Category.default(options.is_synth);
        const vst3_categories = Vst3Category.withDefaults(
            b.allocator,
            options.vst3_categories orelse &.{},
            options.is_synth,
        ) catch @panic("OOM");

        return .{
            .product_name = options.product_name,
            .version = options.version,
            .build_version = options.build_version orelse options.version,
            .bundle_id = bundle_id,

            .microphone_permission_enabled = options.microphone_permission_enabled,
            .microphone_permission_text = options.microphone_permission_text,
            .camera_permission_enabled = options.camera_permission_enabled,
            .camera_permission_text = options.camera_permission_text,
            .bluetooth_permission_enabled = options.bluetooth_permission_enabled,
            .bluetooth_permission_text = options.bluetooth_permission_text,
            .local_network_permission_enabled = options.local_network_permission_enabled,
            .local_network_permission_text = options.local_network_permission_text,
            .send_apple_events_permission_enabled = options.send_apple_events_permission_enabled,
            .send_apple_events_permission_text = options.send_apple_events_permission_text,

            // .icon_big = options.icon_big,
            // .icon_small = options.icon_small,

            .company_copyright = options.company_copyright,
            .company_name = options.company_name,
            .company_website = options.company_website,
            .company_email = options.company_email,

            .document_extensions = options.document_extensions,

            .needs_curl = options.needs_curl,
            .needs_web_browser = options.needs_web_browser,
            .needs_webview2 = options.needs_webview2,
            .needs_store_kit = options.needs_store_kit,

            .plugin_name = options.plugin_name orelse options.product_name,
            .plugin_manufacturer_code = manu_code_hex,
            .plugin_code = plugin_code_hex,
            .formats = options.formats,
            .description = options.description orelse options.product_name,
            .is_synth = options.is_synth,
            .is_midi_effect = options.is_midi_effect,
            .needs_midi_output = options.needs_midi_output,
            .needs_midi_input = options.needs_midi_input,
            .editor_wants_keyboard_focus = options.editor_wants_keyboard_focus,
            .vst2_category = vst2_category,
            .vst3_categories = vst3_categories,
            .vst_num_midi_ins = options.vst_num_midi_ins,
            .vst_num_midi_outs = options.vst_num_midi_outs,
            .plist_to_merge = options.plist_to_merge,

            .use_legacy_compatibility_plugin_code = options.use_legacy_compatibility_plugin_code,
            .vst3_auto_manifest = options.vst3_auto_manifest,
        };
    }

    fn makeValid4cc(b: *std.Build) []const u8 {
        var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
        const random = prng.random();
        var result: [4]u8 = undefined;
        for (0..4) |i| {
            result[i] = switch (i) {
                0 => 'A' + @as(u8, random.uintLessThan(u8, 26)),
                else => 'a' + @as(u8, random.uintLessThan(u8, 26)),
            };
        }
        return b.dupe(result[0..]);
    }
};

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
    flags: []const []const u8 = &.{},
};

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

    var flags = std.ArrayList([]const u8).empty;
    flags.appendSlice(b.allocator, getJuceCommonFlags(b, target, optimize)) catch @panic("OOM");
    flags.appendSlice(b.allocator, options.flags) catch @panic("OOM");
    flags.appendSlice(b.allocator, self.juce_macros.items) catch @panic("OOM");
    flags.append(b.allocator, "-DJUCE_STANDALONE_APPLICATION=1") catch @panic("OOM");

    var juce_modules = std.ArrayList(JuceModule).empty;
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

    const juceaide = Juceaide.create(b, .{
        .upstream = upstream,
        .target = target,
        .optimize = optimize,
        .juce_modules_lib = juce_modules_lib,
    });
    addFlagsToLinkObjects(juceaide.artifact.root_module, flags.items);

    const console_app = b.addExecutable(.{
        .name = options.config.product_name,
        .root_module = self.root_module,
    });
    console_app.root_module.linkLibrary(juce_modules_lib);
    addFlagsToLinkObjects(console_app.root_module, flags.items);

    if (self.binary_data.items.len > 0) {
        for (self.binary_data.items) |opts| {
            const binary_data_lib = BinaryData.create(juceaide, opts);
            for (binary_data_lib.root_module.include_dirs.items) |include_dir| {
                self.root_module.addIncludePath(include_dir.path);
            }
            binary_data = binary_data_lib;
            console_app.linkLibrary(binary_data_lib);
        }
    }

    if (target.result.os.tag.isDarwin()) {
        darwin.sdk.addPaths(b, juce_modules_lib.root_module);
        darwin.sdk.addPaths(b, juceaide.artifact.root_module);
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

    var flags = std.ArrayList([]const u8).empty;
    flags.appendSlice(b.allocator, getJuceCommonFlags(b, target, optimize)) catch @panic("OOM");
    flags.appendSlice(b.allocator, options.flags) catch @panic("OOM");
    flags.appendSlice(b.allocator, self.juce_macros.items) catch @panic("OOM");
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

    const juceaide = Juceaide.create(b, .{
        .upstream = upstream,
        .target = target,
        .optimize = optimize,
        .juce_modules_lib = juce_modules_lib,
    });
    addFlagsToLinkObjects(juceaide.artifact.root_module, flags.items);

    const product_name = options.config.product_name;
    const gui_app = b.addExecutable(.{
        .name = product_name,
        .root_module = self.root_module,
    });
    gui_app.root_module.linkLibrary(juce_modules_lib);
    addFlagsToLinkObjects(gui_app.root_module, flags.items);

    if (self.binary_data.items.len > 0) {
        for (self.binary_data.items) |opts| {
            const binary_data_lib = BinaryData.create(juceaide, opts);
            for (binary_data_lib.root_module.include_dirs.items) |include_dir| {
                self.root_module.addIncludePath(include_dir.path);
            }
            binary_data = binary_data_lib;
            gui_app.linkLibrary(binary_data_lib);
        }
    }

    if (target.result.os.tag.isDarwin()) {
        darwin.sdk.addPaths(b, juce_modules_lib.root_module);
        darwin.sdk.addPaths(b, juceaide.artifact.root_module);
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
        // .windows => {
        // },
        else => @panic("Not implemented yet: only macOS is supported"),
    }

    return .{
        .artifact = artifact.?,
        .install_step = install_step.?,
        .binary_data = binary_data,
    };
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
    var result: Plugin = .{
        .artifacts = .init(b.allocator),
        .install_steps = .init(b.allocator),
    };

    var flags = std.ArrayList([]const u8).empty;
    flags.appendSlice(b.allocator, getJuceCommonFlags(b, target, optimize)) catch @panic("OOM");
    flags.appendSlice(b.allocator, options.flags) catch @panic("OOM");
    flags.appendSlice(b.allocator, self.juce_macros.items) catch @panic("OOM");
    const plugin_macros = PluginMacros.getPluginMacros(b, options.config) catch @panic("OOM");
    flags.appendSlice(b.allocator, plugin_macros) catch @panic("OOM");

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

    const juceaide = Juceaide.create(b, .{
        .upstream = upstream,
        .target = target,
        .optimize = optimize,
        .juce_modules_lib = juce_modules_lib,
    });
    addFlagsToLinkObjects(juceaide.artifact.root_module, flags.items);

    const plugin_shared_lib = b.addLibrary(.{
        .name = "plugin_shared_lib",
        .root_module = self.root_module,
    });
    plugin_shared_lib.linkLibrary(juce_modules_lib);
    addFlagsToLinkObjects(plugin_shared_lib.root_module, flags.items);

    if (self.binary_data.items.len > 0) {
        for (self.binary_data.items) |bd_opts| {
            const binary_data_lib = BinaryData.create(juceaide, bd_opts);
            for (binary_data_lib.root_module.include_dirs.items) |include_dir| {
                self.root_module.addIncludePath(include_dir.path);
            }
            result.binary_data = binary_data_lib;
            plugin_shared_lib.linkLibrary(binary_data_lib);
        }
    }

    if (target.result.os.tag.isDarwin()) {
        darwin.sdk.addPaths(b, juce_modules_lib.root_module);
        darwin.sdk.addPaths(b, juceaide.artifact.root_module);
        darwin.sdk.addPaths(b, plugin_shared_lib.root_module);
    }

    const config = options.config;

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
                vst3.linkLibrary(plugin_shared_lib);

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

                result.artifacts.put(.vst3, vst3) catch @panic("OOM");
                result.install_steps.put(.vst3, vst3_step) catch @panic("OOM");
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
                if (target.result.os.tag.isDarwin()) {
                    darwin.sdk.addPaths(b, standalone_module);
                }

                const standalone = b.addExecutable(.{
                    .name = config.product_name,
                    .root_module = standalone_module,
                });
                standalone.linkLibrary(plugin_shared_lib);

                const standalone_step = b.step("standalone", "Build standalone");

                const install_standalone = darwin.bundle.addInstallBundle(standalone, .{ .plugin = .standalone });
                const install_plist = darwin.bundle.addInstallInfoPlist(juceaide, options.config, .{ .plugin = .standalone });
                const install_pkginfo = darwin.bundle.addInstallPkgInfo(juceaide, config.product_name, .{ .plugin = .standalone });
                const install_nib = darwin.bundle.addInstallNib(b, upstream, config.product_name, .{ .plugin = .standalone });

                standalone_step.dependOn(&install_standalone.step);
                standalone.step.dependOn(&install_plist.step);
                standalone_step.dependOn(&install_pkginfo.step);
                standalone_step.dependOn(&install_nib.step);

                const run_cmd = b.addRunArtifact(standalone);
                run_cmd.step.dependOn(standalone_step);
                const run_step = b.step("run", "Run standalone");
                run_step.dependOn(&run_cmd.step);

                result.artifacts.put(.standalone, standalone) catch @panic("OOM");
                result.install_steps.put(.standalone, standalone_step) catch @panic("OOM");
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
