const std = @import("std");
const builtin = @import("builtin");
const Plugin = @This();
const darwin = @import("darwin.zig");
const windows = @import("windows.zig");
const Juceaide = @import("Juceaide.zig");
const BinaryData = @import("BinaryData.zig");
const setup = @import("setup.zig");
const JuceModule = @import("JuceModule.zig");
const CxxStandard = setup.CxxStandard;
const Config = @import("Config.zig");

juzi: *std.Build.Dependency,
root_module: *std.Build.Module,
binary_data: std.ArrayList(BinaryData.CreateOptions),
cxx_standard: CxxStandard,
config: Config,
juce_modules: []const JuceModule,

// Plugin artifacts and steps are populated by `finalize`.
artifacts: std.AutoHashMapUnmanaged(Format, *std.Build.Step.Compile),
install_steps: std.AutoHashMapUnmanaged(Format, *std.Build.Step),
copy_step: ?*std.Build.Step = null,

// TODO: support more plugin formats
pub const Format = enum {
    vst3,
    standalone,
    // vst,
    au,
    // auv3,
    // aax,
    // lv2,
    // unity,

    pub fn internalIdentifier(self: Format) []const u8 {
        return switch (self) {
            .vst3 => "VST3",
            .standalone => "Standalone Plugin",
            // .vst => "VST",
            .au => "AU",
            // .auv3 => "AUv3 AppExtension",
            // .aax => "AAX",
            // .lv2 => "LV2",
            // .unity => "Unity Plugin",
        };
    }
};

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

    const root_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        // Zig can't build libcpp for MSVC:
        // https://github.com/ziglang/zig/issues/5312
        .link_libcpp = !isWindows,
        // Temporary disable sanitizer on Windows:
        // https://codeberg.org/kengo/juzi/issues/12
        .sanitize_c = if (isWindows) .off else null,
    });

    if (target.result.os.tag.isDarwin()) {
        darwin.addSdkPaths(b, root_module);
    }

    return Plugin{
        .root_module = root_module,
        .juzi = options.juzi,
        .cxx_standard = options.cxx_standard,
        .binary_data = .empty,
        .config = Config.init(b, options.config),
        .juce_modules = options.juce_modules,
        .artifacts = .empty,
        .install_steps = .empty,
    };
}

pub fn finalize(self: *Plugin) void {
    const b = self.root_module.owner;
    const target = self.root_module.resolved_target.?;
    const optimize = self.root_module.optimize.?;
    const config = self.config;
    const juce = self.juzi.builder.dependency("juce", .{});
    self.root_module.addIncludePath(juce.path("modules"));

    const build_ctx: JuceModule.BuildContext = .{
        .builder = b,
        .juce = juce,
        .target = target,
        .optimize = optimize,
        .cxx_standard = self.cxx_standard,
    };
    setup.addJuceModules(self.root_module, self.juce_modules, build_ctx);

    setup.addJuceStandardMacros(self.root_module);
    addJucePluginBuildMacros(self.root_module, config.formats);
    addJucePluginConfigMacros(self.root_module, config);
    linkOptionalLibraries(self.root_module, config);

    const info_text_file = setup.generateInfoText(b, config) catch @panic("Failed to generate Info.txt");

    const plugin_shared_lib = b.addLibrary(.{
        .name = "plugin_shared_lib",
        .root_module = self.root_module,
    });

    const juceaide = Juceaide.create(b, juce);

    if (self.binary_data.items.len > 0) {
        for (self.binary_data.items) |bd_opts| {
            const binary_data_lib = BinaryData.create(juceaide, target, optimize, bd_opts);
            for (binary_data_lib.root_module.include_dirs.items) |include_dir| {
                self.root_module.addIncludePath(include_dir.path);
            }
            plugin_shared_lib.root_module.linkLibrary(binary_data_lib);
        }
    }

    const copy_step = b.step("copy", "Build and copy plugin formats to their default locations");
    self.copy_step = copy_step;

    var plugin_wrapper_macros: std.ArrayList([]const u8) = .empty;
    for (self.root_module.c_macros.items) |macro| {
        if (std.mem.startsWith(u8, macro, "-DJucePlugin_Build_")) continue;
        plugin_wrapper_macros.append(b.allocator, macro) catch @panic("OOM");
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
                addJucePluginBuildMacros(vst3.root_module, &.{.vst3});
                vst3.root_module.c_macros.appendSlice(b.allocator, plugin_wrapper_macros.items) catch @panic("OOM");
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
                    .flags = build_ctx.cxxFlags(&.{}),
                });

                const install_module_info = addInstallModuleInfo(
                    b,
                    juce,
                    vst3.name,
                    .{
                        .target = target,
                        .optimize = optimize,
                        .flags = self.root_module.c_macros.items,
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
                            b.graph.path(.install_prefix, b.fmt("{s}.vst3", .{vst3.name})),
                        );
                        adhoc_sign_run.step.dependOn(&install_plist.step);
                        adhoc_sign_run.step.dependOn(&install_pkginfo.step);
                        adhoc_sign_run.step.dependOn(&install_vst3.step);
                        if (config.vst3_auto_manifest) {
                            adhoc_sign_run.step.dependOn(&install_module_info.step);
                        }
                        vst3_step.dependOn(&adhoc_sign_run.step);

                        const home_dir = b.graph.environ_map.get("HOME").?;
                        var copy_run_step = createCopyRunStep(b, .{
                            .juzi = self.juzi,
                            .src_dir = b.graph.path(.install_prefix, b.fmt("{s}.vst3", .{vst3.name})),
                            .dest_dir = b.fmt("{s}/Library/Audio/Plug-Ins/VST3", .{home_dir}),
                        });
                        copy_run_step.dependOn(vst3_step);
                        copy_step.dependOn(copy_run_step);
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

                        const home_dir = b.graph.environ_map.get("HOME").?;
                        var copy_run_step = createCopyRunStep(b, .{
                            .juzi = self.juzi,
                            .src_dir = b.graph.path(.install_prefix, b.fmt("{s}.vst3", .{vst3.name})),
                            .dest_dir = b.fmt("{s}/.vst3", .{home_dir}),
                        });
                        copy_run_step.dependOn(vst3_step);
                        copy_step.dependOn(copy_run_step);
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

                        const common_dir = b.graph.environ_map.get("CommonProgramW6432").?;
                        var copy_run_step = createCopyRunStep(b, .{
                            .juzi = self.juzi,
                            .src_dir = b.graph.path(.install_prefix, b.fmt("{s}.vst3", .{vst3.name})),
                            .dest_dir = b.fmt("{s}/VST3", .{common_dir}),
                        });
                        copy_run_step.dependOn(vst3_step);
                        copy_step.dependOn(copy_run_step);
                    },
                    else => @panic("unsupported os"),
                }

                self.artifacts.put(b.allocator, .vst3, vst3) catch @panic("OOM");
                self.install_steps.put(b.allocator, .vst3, vst3_step) catch @panic("OOM");
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
                addJucePluginBuildMacros(au.root_module, &.{.au});
                au.root_module.c_macros.appendSlice(b.allocator, plugin_wrapper_macros.items) catch @panic("OOM");
                au.root_module.linkLibrary(plugin_shared_lib);
                au.root_module.addIncludePath(juce.path("modules"));
                au.root_module.addIncludePath(juce.path("modules/juce_audio_plugin_client/AU"));

                var flags: std.ArrayList([]const u8) = .empty;
                flags.appendSlice(b.allocator, build_ctx.cxxFlags(&.{})) catch @panic("OOM");
                // JUCE's AU plugin client can use enum values outside the usual range,
                // which trips UBSan's enum checks when loading debug AU plugins:
                // https://github.com/juce-framework/JUCE/blob/1b460fe0895635a2ab8ac5c00cb5575e33e5dc1e/modules/juce_audio_plugin_client/juce_audio_plugin_client_AU_1.mm#L939-L945
                flags.append(b.allocator, "-fno-sanitize=enum") catch @panic("OOM");

                au.root_module.addCSourceFiles(.{
                    .root = juce.path("modules/juce_audio_plugin_client"),
                    .files = &.{
                        "juce_audio_plugin_client_AU_1.mm",
                        "juce_audio_plugin_client_AU_2.mm",
                    },
                    .flags = flags.items,
                });

                const install_au = darwin.addInstallBundle(au, .{ .plugin = .au });
                const install_plist = darwin.addInstallInfoPlist(juceaide, info_text_file, config, .{ .plugin = .au });
                const install_pkginfo = darwin.addInstallPkgInfo(juceaide, au.name, .{ .plugin = .au });
                const adhoc_sign = darwin.addAdhocSign(
                    b,
                    b.graph.path(.install_prefix, b.fmt("{s}.component", .{au.name})),
                );
                adhoc_sign.step.dependOn(&install_plist.step);
                adhoc_sign.step.dependOn(&install_pkginfo.step);
                adhoc_sign.step.dependOn(&install_au.step);
                au_step.dependOn(&adhoc_sign.step);

                const home_dir = b.graph.environ_map.get("HOME").?;
                var copy_run_step = createCopyRunStep(b, .{
                    .juzi = self.juzi,
                    .src_dir = b.graph.path(.install_prefix, b.fmt("{s}.component", .{au.name})),
                    .dest_dir = b.fmt("{s}/Library/Audio/Plug-Ins/Components", .{home_dir}),
                });
                copy_run_step.dependOn(au_step);
                copy_step.dependOn(copy_run_step);

                self.artifacts.put(b.allocator, .au, au) catch @panic("OOM");
                self.install_steps.put(b.allocator, .au, au_step) catch @panic("OOM");
            },
            .standalone => {
                const standalone_step = b.step("standalone", "Build standalone");
                const standalone = b.addExecutable(.{
                    .name = config.product_name,
                    .root_module = b.createModule(.{ .target = target, .optimize = optimize }),
                    .win32_manifest = windows.createManifest(b),
                });
                addJucePluginBuildMacros(standalone.root_module, &.{.standalone});
                standalone.root_module.c_macros.appendSlice(b.allocator, plugin_wrapper_macros.items) catch @panic("OOM");
                standalone.root_module.linkLibrary(plugin_shared_lib);
                standalone.root_module.addIncludePath(juce.path("modules"));
                standalone.root_module.addCSourceFiles(.{
                    .root = juce.path("modules/juce_audio_plugin_client"),
                    .files = &.{"juce_audio_plugin_client_Standalone.cpp"},
                    .flags = build_ctx.cxxFlags(&.{}),
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

                self.artifacts.put(b.allocator, .standalone, standalone) catch @panic("OOM");
                self.install_steps.put(b.allocator, .standalone, standalone_step) catch @panic("OOM");
            },
        }
    }
}

const AddInstallModuleInfoOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    flags: []const []const u8 = &.{},
};

// Creates the install step for generating and installing the VST3 moduleinfo.json file.
fn addInstallModuleInfo(
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

    var flags: std.ArrayList([]const u8) = .empty;
    flags.appendSlice(b.allocator, options.flags) catch @panic("OOM");
    flags.append(b.allocator, CxxStandard.cxx17.flag()) catch @panic("OOM");

    manifest_helper.root_module.addCSourceFiles(.{
        .root = juce.path("modules/juce_audio_plugin_client/VST3"),
        .files = &.{"juce_VST3ManifestHelper.cpp"},
        .flags = flags.items,
    });

    const manifest_helper_cmd = b.addRunArtifact(manifest_helper);
    const out_module_info = manifest_helper_cmd.captureStdOut(.{});
    const install_module_info = b.addInstallFileWithDir(
        out_module_info,
        .prefix,
        b.fmt("{s}.vst3/Contents/Resources/moduleinfo.json", .{product_name}),
    );
    setup.addJuceStandardMacros(manifest_helper.root_module);

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

pub fn addBinaryData(self: *Plugin, bd: BinaryData.CreateOptions) void {
    const b = self.root_module.owner;
    self.binary_data.append(b.allocator, bd) catch @panic("OOM");
}

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

pub const Vst3Category = enum {
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
        existing_categories: []const Vst3Category,
        is_synth: bool,
    ) ![]const Vst3Category {
        if (existing_categories.len == 0) {
            return if (is_synth) &.{ .Instrument, .Synth } else &.{.Fx};
        }

        var categArray: std.ArrayList(Vst3Category) = .empty;

        for (existing_categories) |category| {
            try categArray.append(allocator, category);
        }

        const contains_instrument = std.mem.containsAtLeastScalar(
            Vst3Category,
            existing_categories,
            .Instrument,
            1,
        );
        const contains_fx = std.mem.containsAtLeastScalar(
            Vst3Category,
            existing_categories,
            .Fx,
            1,
        );

        if (!contains_instrument and !contains_fx) {
            try categArray.insert(allocator, 0, if (is_synth) .Instrument else .Fx);
        } else {
            if (contains_instrument) {
                const inst_index = std.mem.indexOf(Vst3Category, existing_categories, &.{.Instrument}).?;
                const inst = categArray.orderedRemove(inst_index);
                try categArray.insert(allocator, 0, inst);
            }

            if (contains_fx) {
                const fx_index = std.mem.indexOf(Vst3Category, existing_categories, &.{.Fx}).?;
                const fx = categArray.orderedRemove(fx_index);
                try categArray.insert(allocator, 0, fx);
            }
        }

        return try categArray.toOwnedSlice(allocator);
    }

    // Converts the category list into a `|`-separated VST3 category string.
    // e.g. `.{ .Fx, .Reverb }` → "Fx|Reverb"
    pub fn join(allocator: std.mem.Allocator, categories: []const Vst3Category) []const u8 {
        var categoryStrings: std.ArrayList([]const u8) = .empty;
        defer categoryStrings.deinit(allocator);
        for (categories) |category| {
            categoryStrings.append(allocator, category.internalIdentifier()) catch @panic("OOM");
        }
        return std.mem.join(allocator, "|", categoryStrings.items) catch @panic("OOM");
    }
};

pub const AudioUnitMainType = enum {
    kAudioUnitType_Effect,
    kAudioUnitType_FormatConverter,
    kAudioUnitType_Generator,
    kAudioUnitType_MIDIProcessor,
    kAudioUnitType_Mixer,
    kAudioUnitType_MusicDevice,
    kAudioUnitType_MusicEffect,
    kAudioUnitType_OfflineEffect,
    kAudioUnitType_Output,
    kAudioUnitType_Panner,

    pub fn categoryCode(self: AudioUnitMainType) []const u8 {
        return switch (self) {
            .kAudioUnitType_Effect => "\'aufx\'",
            .kAudioUnitType_FormatConverter => "\'aufc\'",
            .kAudioUnitType_Generator => "\'augn\'",
            .kAudioUnitType_MIDIProcessor => "\'aumi\'",
            .kAudioUnitType_Mixer => "\'aumx\'",
            .kAudioUnitType_MusicDevice => "\'aumu\'",
            .kAudioUnitType_MusicEffect => "\'aumf\'",
            .kAudioUnitType_OfflineEffect => "\'auol\'",
            .kAudioUnitType_Output => "\'auou\'",
            .kAudioUnitType_Panner => "\'aupn\'",
        };
    }
};

/// Defines a `JucePlugin_Build_<FORMAT>` macro for each plugin format,
/// setting it to `1` when active and `0` otherwise.
fn addJucePluginBuildMacros(module: *std.Build.Module, active_formats: []const Format) void {
    inline for (@typeInfo(Format).@"enum".field_values) |field_value| {
        const format: Format = @fromBackingInt(@intCast(field_value));
        const is_active = if (std.mem.containsAtLeast(Format, active_formats, 1, &.{format})) "1" else "0";
        switch (format) {
            .vst3 => module.addCMacro("JucePlugin_Build_VST3", is_active),
            .au => module.addCMacro("JucePlugin_Build_AU", is_active),
            .standalone => module.addCMacro("JucePlugin_Build_Standalone", is_active),
        }
    }
}

fn addJucePluginConfigMacros(m: *std.Build.Module, config: Config) void {
    const b = m.owner;
    const macros = &.{
        b.fmt("-DJUCE_STANDALONE_APPLICATION={s}", .{"JucePlugin_Build_Standalone"}),
        b.fmt("-DJucePlugin_IsSynth={d}", .{@intFromBool(config.is_synth)}),
        b.fmt("-DJucePlugin_ManufacturerCode=0x{x}", .{config.plugin_manufacturer_code}),
        b.fmt("-DJucePlugin_Manufacturer=\"{s}\"", .{config.company_name}),
        b.fmt("-DJucePlugin_ManufacturerWebsite=\"{s}\"", .{config.company_website}),
        b.fmt("-DJucePlugin_ManufacturerEmail=\"{s}\"", .{config.company_email}),
        b.fmt("-DJucePlugin_PluginCode=0x{x}", .{config.plugin_code}),
        b.fmt("-DJucePlugin_ProducesMidiOutput={d}", .{@intFromBool(config.needs_midi_output)}),
        b.fmt("-DJucePlugin_IsMidiEffect={d}", .{@intFromBool(config.is_midi_effect)}),
        b.fmt("-DJucePlugin_WantsMidiInput={d}", .{@intFromBool(config.needs_midi_input)}),
        b.fmt("-DJucePlugin_EditorRequiresKeyboardFocus={d}", .{@intFromBool(config.editor_wants_keyboard_focus)}),
        b.fmt("-DJucePlugin_Name=\"{s}\"", .{config.plugin_name}),
        b.fmt("-DJucePlugin_Desc=\"{s}\"", .{config.description}),
        b.fmt("-DJucePlugin_Version={s}", .{config.version}),
        b.fmt("-DJucePlugin_VersionString=\"{s}\"", .{config.version}),
        b.fmt("-DJucePlugin_VersionCode={s}", .{semanticVersionToVersionCode(b, config.version)}),
        b.fmt("-DJucePlugin_VSTUniqueID={s}", .{"JucePlugin_PluginCode"}),
        b.fmt("-DJucePlugin_VSTCategory={s}", .{@tagName(config.vst2_category)}),
        b.fmt("-DJucePlugin_Vst3Category=\"{s}\"", .{Vst3Category.join(b.allocator, config.vst3_categories)}),
        b.fmt("-DJucePlugin_VSTNumMidiInputs={d}", .{config.vst_num_midi_ins}),
        b.fmt("-DJucePlugin_VSTNumMidiOutputs={d}", .{config.vst_num_midi_outs}),
        b.fmt("-DJucePlugin_AUMainType={s}", .{config.au_main_type.categoryCode()}),
        b.fmt("-DJucePlugin_AUSubType={s}", .{"JucePlugin_PluginCode"}),
        b.fmt("-DJucePlugin_AUExportPrefix={s}", .{config.au_export_prefix}),
        b.fmt("-DJucePlugin_AUExportPrefixQuoted=\"{s}\"", .{config.au_export_prefix}),
        b.fmt("-DJucePlugin_AUManufacturerCode={s}", .{"JucePlugin_ManufacturerCode"}),
        b.fmt("-DJucePlugin_CFBundleIdentifier={s}", .{config.bundle_id}),

        // TODO:
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
    };

    m.c_macros.appendSlice(b.allocator, macros) catch @panic("OOM");
}

fn semanticVersionToVersionCode(b: *std.Build, ver: []const u8) []const u8 {
    const version = std.SemanticVersion.parse(ver) catch |err| @panic(@errorName(err));
    const v = (version.major << 16) | (version.minor << 8) | version.patch;
    return b.fmt("0x{X}", .{v});
}

const CopyOptions = struct {
    juzi: *std.Build.Dependency,
    src_dir: std.Build.LazyPath,
    dest_dir: []const u8,
};

fn createCopyRunStep(b: *std.Build, options: CopyOptions) *std.Build.Step {
    const mod = b.createModule(.{
        .target = b.graph.host,
        .optimize = .debug,
        .root_source_file = options.juzi.path("src/copy.zig"),
    });
    const copy = b.addExecutable(.{
        .name = "copy",
        .root_module = mod,
    });
    const copy_run = b.addRunArtifact(copy);
    copy_run.addDirectoryArg2(options.src_dir, .{});
    copy_run.addArg(options.dest_dir);

    return &copy_run.step;
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
