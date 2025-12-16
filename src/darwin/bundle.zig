const std = @import("std");
const ProjectConfig = @import("../ProjectConfig.zig");
const PluginFormat = @import("../plugin/format.zig").PluginFormat;
const Juceaide = @import("../Juceaide.zig");

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
                .au => "component",
            },
        };
    }
    pub fn isPlugin(self: ProductKind) bool {
        return switch (self) {
            .plugin => true,
            else => false,
        };
    }
};

// Creates the install step for placing the artifact in a macOS bundle structure.
pub fn addInstallBundle(
    artifact: *std.Build.Step.Compile,
    kind: ProductKind,
) *std.Build.Step.InstallArtifact {
    const b = artifact.step.owner;
    const bundle_subpath = b.fmt("{s}.{s}/Contents/MacOS", .{ artifact.name, kind.bundleTypeIdentifier() });
    const install_bundle = b.addInstallArtifact(artifact, .{
        .dest_dir = .{ .override = .{ .custom = bundle_subpath } },
        .dest_sub_path = artifact.name,
    });
    return install_bundle;
}

// Creates the install step for generating and installing the bundle's Info.plist.
pub fn addInstallInfoPlist(
    juceaide: Juceaide,
    config: ProjectConfig,
    kind: ProductKind,
) *std.Build.Step.InstallFile {
    const b = juceaide.artifact.root_module.owner;
    const plist_cmd = b.addRunArtifact(juceaide.artifact);
    const input_info_file = generateInfoText(b, config, kind.isPlugin()) catch @panic("Failed to generate Info.txt");
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

    return install_plist;
}

// Creates the install step for generating and installing the bundle's PkgInfo file.
pub fn addInstallPkgInfo(
    juceaide: Juceaide,
    product_name: []const u8,
    kind: ProductKind,
) *std.Build.Step.InstallFile {
    const b = juceaide.artifact.root_module.owner;
    const pkginfo_cmd = b.addRunArtifact(juceaide.artifact);
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

    return install_pkginfo;
}

// Creates the install step for installing the .nib file. I don’t yet fully
// understand how this .nib file is used, and the installed result is not
// yet verified to work correctly.
pub fn addInstallNib(
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

pub fn generateInfoText(b: *std.Build, config: ProjectConfig, is_plugin: bool) !std.Build.LazyPath {
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
    try appendRecord(&buf, b.allocator, "IS_PLUGIN", toString(is_plugin));
    // try appendRecord(&buf, b.allocator, "ICLOUD_PERMISSIONS_ENABLED", toString(config.icloud_permissions_enabled));
    // try appendRecord(&buf, b.allocator, "IS_AU_PLUGIN_HOST", toString(config.is_au_plugin_host));

    const wf = b.addWriteFiles();
    _ = wf.add("Info.txt", buf.items);

    return wf.getDirectory();
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
