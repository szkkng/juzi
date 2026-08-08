const std = @import("std");
const JuceModule = @import("JuceModule.zig");
const Config = @import("plugin/Config.zig");
const Format = @import("plugin/format.zig").Format;

pub const ModuleMap = std.StringHashMapUnmanaged(JuceModule);

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

pub fn resolveModules(
    b: *std.Build,
    requested_modules: []const JuceModule,
) ModuleMap {
    var modules: ModuleMap = .empty;

    for (requested_modules) |juce_module| {
        collectModule(b, &modules, juce_module);
    }

    return modules;
}

pub fn addModules(
    root_module: *std.Build.Module,
    modules: ModuleMap,
    ctx: JuceModule.BuildContext,
) void {
    var iter = modules.valueIterator();
    while (iter.next()) |module| {
        module.*.configure(root_module, ctx);
    }
}

fn collectModule(
    b: *std.Build,
    modules: *ModuleMap,
    juce_module: JuceModule,
) void {
    if (modules.contains(juce_module.name)) return;

    modules.put(b.allocator, juce_module.name, juce_module) catch @panic("OOM");
    for (juce_module.deps) |dependency| {
        collectModule(b, modules, dependency);
    }
}

pub fn resolveRequiredFlags(
    b: *std.Build,
    modules: ModuleMap,
    cxx_standard: CxxStandard,
    target: std.Build.ResolvedTarget,
    extra_flags: []const []const u8,
) JuceModule.RequiredFlags {
    var common: std.ArrayList([]const u8) = .empty;
    common.appendSlice(b.allocator, extra_flags) catch @panic("OOM");
    common.appendSlice(b.allocator, getModuleAvailableDefs(b, modules)) catch @panic("OOM");
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

    if (target.result.os.tag == .windows) {
        // Suppress `error: argument unused during compilation: '-nostdinc++'`
        cxx.append(b.allocator, "-Wno-error=unused-command-line-argument") catch @panic("OOM");
    }

    return .{
        .c = c_flags,
        .cxx = cxx.toOwnedSlice(b.allocator) catch @panic("OOM"),
    };
}

pub fn addStandardDefs(module: *std.Build.Module, optimize: std.builtin.OptimizeMode) void {
    module.addCMacro("JUCE_GLOBAL_MODULE_SETTINGS_INCLUDED", "1");
    module.addCMacro(if (optimize == .Debug) "DEBUG" else "NDEBUG", "1");
}

/// Defines a `JucePlugin_Build_<FORMAT>` macro for each plugin format,
/// setting it to `1` when active and `0` otherwise.
pub fn addPluginDefinitions(module: *std.Build.Module, active_formats: []const Format) void {
    inline for (@typeInfo(Format).@"enum".fields) |field| {
        const format: Format = @enumFromInt(field.value);
        const is_active = if (std.mem.containsAtLeast(Format, active_formats, 1, &.{format})) "1" else "0";
        switch (format) {
            .vst3 => module.addCMacro("JucePlugin_Build_VST3", is_active),
            .au => module.addCMacro("JucePlugin_Build_AU", is_active),
            .standalone => module.addCMacro("JucePlugin_Build_Standalone", is_active),
        }
    }
}

fn getModuleAvailableDefs(
    b: *std.Build,
    modules: ModuleMap,
) []const []const u8 {
    var defs: std.ArrayList([]const u8) = .empty;
    var names = modules.keyIterator();
    while (names.next()) |name| {
        defs.append(b.allocator, b.fmt("-DJUCE_MODULE_AVAILABLE_{s}=1", .{name.*})) catch @panic("OOM");
    }
    return defs.toOwnedSlice(b.allocator) catch @panic("OOM");
}

pub fn addFlagsToLinkObjects(module: *std.Build.Module, flags: []const []const u8) void {
    const b = module.owner;
    for (module.link_objects.items) |link_object| {
        switch (link_object) {
            .c_source_file => updateFlags(std.Build.Module.CSourceFile, b, link_object.c_source_file, flags),
            .c_source_files => updateFlags(std.Build.Module.CSourceFiles, b, link_object.c_source_files, flags),
            else => {},
        }
    }
}

fn updateFlags(T: type, b: *std.Build, source: *T, flags: []const []const u8) void {
    if (T != std.Build.Module.CSourceFile and T != std.Build.Module.CSourceFiles) {
        @compileError("Needs to be CSourceFile or CSourceFiles");
    }
    source.flags = std.mem.concat(b.allocator, []const u8, &.{
        source.flags,
        flags,
    }) catch @panic("OOM");
}

pub fn generateInfoText(b: *std.Build, config: Config) !std.Build.LazyPath {
    var buf: std.ArrayList(u8) = .empty;

    try appendRecord(&buf, b.allocator, "EXECUTABLE_NAME", config.product_name);
    try appendRecord(&buf, b.allocator, "VERSION", config.version);
    try appendRecord(&buf, b.allocator, "BUILD_VERSION", config.build_version);
    try appendRecord(&buf, b.allocator, "PLIST_TO_MERGE", config.plist_to_merge);
    try appendRecord(&buf, b.allocator, "BUNDLE_ID", config.bundle_id);
    try appendRecord(&buf, b.allocator, "XCODE_EXTRA_PLIST_ENTRIES", ""); // JUCE_XCODE_EXTRA_PLIST_ENTRIES
    try appendRecord(&buf, b.allocator, "MICROPHONE_PERMISSION_ENABLED", toString(config.microphone_permission_enabled));
    try appendRecord(&buf, b.allocator, "MICROPHONE_PERMISSION_TEXT", config.microphone_permission_text);
    try appendRecord(&buf, b.allocator, "CAMERA_PERMISSION_ENABLED", toString(config.camera_permission_enabled));
    try appendRecord(&buf, b.allocator, "CAMERA_PERMISSION_TEXT", config.camera_permission_text);
    try appendRecord(&buf, b.allocator, "BLUETOOTH_PERMISSION_ENABLED", toString(config.bluetooth_permission_enabled));
    try appendRecord(&buf, b.allocator, "BLUETOOTH_PERMISSION_TEXT", config.bluetooth_permission_text);
    try appendRecord(&buf, b.allocator, "LOCAL_NETWORK_PERMISSION_ENABLED", toString(config.local_network_permission_enabled));
    try appendRecord(&buf, b.allocator, "LOCAL_NETWORK_PERMISSION_TEXT", config.local_network_permission_text);
    try appendRecord(&buf, b.allocator, "SEND_APPLE_EVENTS_PERMISSION_ENABLED", toString(config.send_apple_events_permission_enabled));
    try appendRecord(&buf, b.allocator, "SEND_APPLE_EVENTS_PERMISSION_TEXT", config.send_apple_events_permission_text);
    // try appendRecord(&buf, b.allocator, "SHOULD_ADD_STORYBOARD", toString(config.should_add_storyboard));
    // try appendRecord(&buf, b.allocator, "LAUNCH_STORYBOARD_FILE", config.launch_storyboard_file orelse "");
    // try appendRecord(&buf, b.allocator, "ICON_FILE", config.icon_file orelse "");
    try appendRecord(&buf, b.allocator, "PROJECT_NAME", config.product_name);
    try appendRecord(&buf, b.allocator, "COMPANY_COPYRIGHT", config.company_copyright);
    try appendRecord(&buf, b.allocator, "COMPANY_NAME", config.company_name);
    try appendRecord(&buf, b.allocator, "DOCUMENT_EXTENSIONS", try std.mem.join(b.allocator, ";", config.document_extensions));
    // try appendRecord(&buf, b.allocator, "FILE_SHARING_ENABLED", toString(config.file_sharing_enabled));
    // try appendRecord(&buf, b.allocator, "DOCUMENT_BROWSER_ENABLED", toString(config.document_browser_enabled));
    // try appendRecord(&buf, b.allocator, "STATUS_BAR_HIDDEN", toString(config.status_bar_hidden));
    // try appendRecord(&buf, b.allocator, "REQUIRES_FULL_SCREEN", toString(config.requires_full_screen));
    // try appendRecord(&buf, b.allocator, "BACKGROUND_AUDIO_ENABLED", toString(config.background_audio_enabled));
    // try appendRecord(&buf, b.allocator, "BACKGROUND_BLE_ENABLED", toString(config.background_ble_enabled));
    // try appendRecord(&buf, b.allocator, "PUSH_NOTIFICATIONS_ENABLED", toString(config.push_notifications_enabled));
    // try appendRecord(&buf, b.allocator, "NETWORK_MULTICAST_ENABLED", toString(config.network_multicast_enabled));
    try appendRecord(&buf, b.allocator, "PLUGIN_MANUFACTURER_CODE", config.plugin_manufacturer_code);
    try appendRecord(&buf, b.allocator, "PLUGIN_CODE", config.plugin_code);
    // try appendRecord(&buf, b.allocator, "IPHONE_SCREEN_ORIENTATIONS", config.iphone_screen_orientations);
    // try appendRecord(&buf, b.allocator, "IPAD_SCREEN_ORIENTATIONS", config.ipad_screen_orientations);
    try appendRecord(&buf, b.allocator, "PLUGIN_NAME", config.plugin_name);
    try appendRecord(&buf, b.allocator, "PLUGIN_MANUFACTURER", config.company_name);
    try appendRecord(&buf, b.allocator, "PLUGIN_DESCRIPTION", config.description);
    try appendRecord(&buf, b.allocator, "PLUGIN_AU_EXPORT_PREFIX", config.au_export_prefix);
    try appendRecord(&buf, b.allocator, "PLUGIN_AU_MAIN_TYPE", config.au_main_type.categoryCode());
    try appendRecord(&buf, b.allocator, "IS_AU_SANDBOX_SAFE", toString(config.au_sandbox_safe));
    try appendRecord(&buf, b.allocator, "IS_PLUGIN_SYNTH", toString(config.is_synth));
    // try appendRecord(&buf, b.allocator, "IS_PLUGIN_ARA_EFFECT", toString(config.is_ara_effect));
    try appendRecord(&buf, b.allocator, "SUPPRESS_AU_PLIST_RESOURCE_USAGE", toString(config.suppress_au_plist_resource_usage));
    // try appendRecord(&buf, b.allocator, "HARDENED_RUNTIME_ENABLED", toString(config.hardened_runtime_enabled));
    // try appendRecord(&buf, b.allocator, "APP_SANDBOX_ENABLED", toString(config.app_sandbox_enabled));
    // try appendRecord(&buf, b.allocator, "APP_SANDBOX_INHERIT", toString(config.app_sandbox_inherit));
    // try appendRecord(&buf, b.allocator, "HARDENED_RUNTIME_OPTIONS", config.hardened_runtime_options);
    // try appendRecord(&buf, b.allocator, "APP_SANDBOX_OPTIONS", config.app_sandbox_options);
    // try appendRecord(&buf, b.allocator, "APP_SANDBOX_FILE_ACCESS_HOME_RO", config.app_sandbox_file_access_home_ro);
    // try appendRecord(&buf, b.allocator, "APP_SANDBOX_FILE_ACCESS_ABS_RO", config.app_sandbox_file_access_abs_ro);
    // try appendRecord(&buf, b.allocator, "APP_SANDBOX_FILE_ACCESS_ABS_RW", config.app_sandbox_file_access_abs_rw);
    // try appendRecord(&buf, b.allocator, "APP_SANDBOX_EXCEPTION_IOKIT", config.app_sandbox_exception_iokit);
    // try appendRecord(&buf, b.allocator, "APP_GROUPS_ENABLED", toString(config.app_groups_enabled));
    // try appendRecord(&buf, b.allocator, "APP_GROUP_IDS", config.app_group_ids);
    try appendRecord(&buf, b.allocator, "IS_PLUGIN", toString(true));
    // try appendRecord(&buf, b.allocator, "ICLOUD_PERMISSIONS_ENABLED", toString(config.icloud_permissions_enabled));
    // try appendRecord(&buf, b.allocator, "IS_AU_PLUGIN_HOST", toString(config.is_au_plugin_host));

    const wf = b.addWriteFiles();
    const path = wf.add("Info.txt", buf.items);
    return path;
}

fn toString(value: ?bool) []const u8 {
    if (value) |v| {
        return if (v) "TRUE" else "FALSE";
    } else {
        return "";
    }
}

fn appendRecord(buf: *std.ArrayList(u8), gpa: std.mem.Allocator, key: []const u8, value: []const u8) !void {
    const rs: u8 = 30; // Record Separator
    const us: u8 = 31; // Unit Separator

    try buf.appendSlice(gpa, key);
    try buf.append(gpa, us);
    try buf.appendSlice(gpa, value);
    try buf.append(gpa, rs);
}
