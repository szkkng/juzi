const std = @import("std");
const Setup = @This();
const darwin = @import("darwin.zig");
const Juceaide = @import("Juceaide.zig");
const BinaryData = Juceaide.BinaryData;
pub const JuceModule = @import("modules.zig").JuceModule;

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

pub const Vst2Category = enum {
    kPlugCategUnknown,
    kPlugCategEffect,
    kPlugCategSynth,
    kPlugCategAnalysis,
    kPlugCategMastering,
    kPlugCategSpacializer,
    kPlugCategRoomFx,
    kPlugSurroundFx,
    kPlugCategRestoration,
    kPlugCategOfflineProcess,
    kPlugCategShell,
    kPlugCategGenerator,

    pub fn default(is_synth: bool) Vst2Category {
        return if (is_synth) .kPlugCategSynth else .kPlugCategEffect;
    }
};

const Vst3Category = enum {
    Fx,
    Instrument,
    Analyzer,
    Delay,
    Distortion,
    Drum,
    Dynamics,
    EQ,
    External,
    Filter,
    Generator,
    Mastering,
    Modulation,
    Mono,
    Network,
    NoOfflineProcess,
    OnlyOfflineProcess,
    OnlyRT,
    Pitch_Shift,
    Restoration,
    Reverb,
    Sampler,
    Spatial,
    Stereo,
    Surround,
    Synth,
    Tools,
    Up_Downmix,

    pub fn internalIdentifier(self: Vst3Category) []const u8 {
        return switch (self) {
            .Pitch_Shift => "Pitch Shift",
            .Up_Downmix => "Up-Downmix",
            else => @tagName(self),
        };
    }

    // Returns a new list of categories with defaults applied.
    // Ensures `.Fx` or `.Instrument` appears first if omitted, depending on `is_synth`.
    pub fn withDefaults(
        allocator: std.mem.Allocator,
        exsiting_categories: []const Vst3Category,
        is_synth: bool,
    ) ![]const Vst3Category {
        if (exsiting_categories.len == 0) {
            return if (is_synth) &.{ .Instrument, .Synth } else &.{.Fx};
        }

        var categArray = std.ArrayList(Vst3Category).empty;

        for (exsiting_categories) |category| {
            try categArray.append(allocator, category);
        }

        const contains_instrument = std.mem.containsAtLeastScalar(
            Vst3Category,
            exsiting_categories,
            1,
            .Instrument,
        );
        const contains_fx = std.mem.containsAtLeastScalar(
            Vst3Category,
            exsiting_categories,
            1,
            .Fx,
        );

        if (!contains_instrument and !contains_fx) {
            try categArray.insert(allocator, 0, if (is_synth) .Instrument else .Fx);
        } else {
            if (contains_instrument) {
                const inst_index = std.mem.indexOf(Vst3Category, exsiting_categories, &.{.Instrument}).?;
                const inst = categArray.orderedRemove(inst_index);
                try categArray.insert(allocator, 0, inst);
            }

            if (contains_fx) {
                const fx_index = std.mem.indexOf(Vst3Category, exsiting_categories, &.{.Fx}).?;
                const fx = categArray.orderedRemove(fx_index);
                try categArray.insert(allocator, 0, fx);
            }
        }

        return try categArray.toOwnedSlice(allocator);
    }

    // Converts the category list into a `|`-separated VST3 category string.
    // e.g. `.{ .Fx, .Reverb }` → "Fx|Reverb"
    pub fn join(allocator: std.mem.Allocator, categories: []const Vst3Category) ![]const u8 {
        var categoryStrings = std.ArrayList([]const u8).empty;
        defer categoryStrings.deinit(allocator);
        for (categories) |category| {
            try categoryStrings.append(allocator, category.internalIdentifier());
        }
        return try std.mem.join(allocator, "|", categoryStrings.items);
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
    plugin_code: ?[]const u8 = null,
    formats: []const PluginFormat = &.{},
    description: ?[]const u8 = null,
    // copy_plugin_after_build: ?bool = false,
    is_synth: bool = false,
    is_midi_effect: bool = false,
    needs_midi_output: bool = false,
    needs_midi_input: bool = false,
    editor_wants_keyboard_focus: bool = false,
    vst3_auto_manifest: bool = true,
    vst2_category: ?Vst2Category = null,
    vst3_categories: ?[]const Vst3Category = null,
    vst_num_midi_ins: u8 = 16,
    vst_num_midi_outs: u8 = 16,
};

juzi_dep: *std.Build.Dependency,
root_module: *std.Build.Module,
juce_macros: std.ArrayList([]const u8),
juce_binary_data: std.ArrayList(BinaryData),

pub fn init(juzi_dep: *std.Build.Dependency, root_module: *std.Build.Module) Setup {
    const upstream = juzi_dep.builder.dependency("upstream", .{});
    root_module.addIncludePath(upstream.path("modules"));

    return Setup{
        .root_module = root_module,
        .juzi_dep = juzi_dep,
        .juce_macros = .empty,
        .juce_binary_data = .empty,
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

    if (self.juce_binary_data.items.len > 0) {
        for (self.juce_binary_data.items) |bd| {
            const binary_data_lib = juceaide.addBinaryData(b, bd);
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

    if (self.juce_binary_data.items.len > 0) {
        for (self.juce_binary_data.items) |bd| {
            const binary_data_lib = juceaide.addBinaryData(b, bd);
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
    var plugin: Plugin = .{
        .artifacts = .init(b.allocator),
        .install_steps = .init(b.allocator),
    };

    var flags = std.ArrayList([]const u8).empty;
    flags.appendSlice(b.allocator, getJuceCommonFlags(b, target, optimize)) catch @panic("OOM");
    flags.appendSlice(b.allocator, options.flags) catch @panic("OOM");
    flags.appendSlice(b.allocator, self.juce_macros.items) catch @panic("OOM");
    const plugin_defs = getPluginDefs(b, options.config) catch @panic("OOM");
    flags.appendSlice(b.allocator, plugin_defs) catch @panic("OOM");

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

    if (self.juce_binary_data.items.len > 0) {
        for (self.juce_binary_data.items) |bd| {
            const binary_data_lib = juceaide.addBinaryData(b, bd);
            for (binary_data_lib.root_module.include_dirs.items) |include_dir| {
                self.root_module.addIncludePath(include_dir.path);
            }
            plugin.binary_data = binary_data_lib;
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

pub fn addBinaryData(self: *Setup, bd: BinaryData) void {
    const b = self.root_module.owner;
    self.juce_binary_data.append(b.allocator, bd) catch @panic("OOM");
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

    if (options.target.result.os.tag.isDarwin()) {
        darwin.sdk.addPaths(b, manifest_helper.root_module);
    }

    return install_module_info;
}

fn getPluginDefs(b: *std.Build, config: ProjectConfig) ![]const []const u8 {
    var flags = std.ArrayList([]const u8).empty;

    try flags.append(b.allocator, b.fmt("-DJUCE_STANDALONE_APPLICATION={s}", .{"JucePlugin_Build_Standalone"}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_IsSynth={d}", .{@intFromBool(config.is_synth)}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_ManufacturerCode=0x{x}", .{config.plugin_manufacturer_code}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_Manufacturer=\"{s}\"", .{config.company_name}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_ManufacturerWebsite=\"{s}\"", .{config.company_website}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_ManufacturerEmail=\"{s}\"", .{config.company_email}));

    const plugin_code = config.plugin_code orelse makeValid4cc(b);
    try flags.append(b.allocator, b.fmt("-DJucePlugin_PluginCode=0x{x}", .{plugin_code}));

    try flags.append(b.allocator, b.fmt("-DJucePlugin_ProducesMidiOutput={d}", .{@intFromBool(config.needs_midi_output)}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_IsMidiEffect={d}", .{@intFromBool(config.is_midi_effect)}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_WantsMidiInput={d}", .{@intFromBool(config.needs_midi_input)}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_EditorRequiresKeyboardFocus={d}", .{@intFromBool(config.editor_wants_keyboard_focus)}));

    try flags.append(b.allocator, b.fmt("-DJucePlugin_Name=\"{s}\"", .{config.plugin_name orelse config.product_name}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_Desc=\"{s}\"", .{config.description orelse config.product_name}));

    try flags.append(b.allocator, b.fmt("-DJucePlugin_Version={s}", .{config.version}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_VersionString=\"{s}\"", .{config.version}));
    const version_code = try semanticVersionToVersionCode(b, config.version);
    try flags.append(b.allocator, b.fmt("-DJucePlugin_VersionCode={s}", .{version_code}));

    try flags.append(b.allocator, b.fmt("-DJucePlugin_VSTUniqueID={s}", .{"JucePlugin_PluginCode"}));

    const vst_category = config.vst2_category orelse Vst2Category.default(config.is_synth);
    try flags.append(b.allocator, b.fmt("-DJucePlugin_VSTCategory={s}", .{@tagName(vst_category)}));
    const vst3_categories = try Vst3Category.withDefaults(b.allocator, config.vst3_categories orelse &.{}, config.is_synth);
    try flags.append(b.allocator, b.fmt("-DJucePlugin_Vst3Category=\"{s}\"", .{try Vst3Category.join(b.allocator, vst3_categories)}));

    try flags.append(b.allocator, b.fmt("-DJucePlugin_VSTNumMidiInputs={d}", .{config.vst_num_midi_ins}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_VSTNumMidiOutputs={d}", .{config.vst_num_midi_outs}));

    // TODO: add more JUCE plugin macros
    // JucePlugin_AUMainType
    // JucePlugin_AUSubType
    // JucePlugin_AUExportPrefix
    // JucePlugin_AUExportPrefixQuoted
    // JucePlugin_AUManufacturerCode

    // JucePlugin_AAXIdentifier
    // JucePlugin_AAXManufacturerCode
    // JucePlugin_AAXProductId
    // JucePlugin_AAXCategory
    // JucePlugin_AAXDisableBypass
    // JucePlugin_AAXDisableMultiMono

    // JucePlugin_Enable_ARA
    // JucePlugin_ARAFactoryID
    // JucePlugin_ARADocumentArchiveID
    // JucePlugin_ARACompatibleArchiveIDs
    // JucePlugin_ARAContentTypes
    // JucePlugin_ARATransformationFlags

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

fn semanticVersionToVersionCode(b: *std.Build, ver: []const u8) ![]const u8 {
    const version = try std.SemanticVersion.parse(ver);
    const v = (version.major << 16) | (version.minor << 8) | version.patch;
    return b.fmt("0x{X}", .{v});
}
