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
                // .au => "component",
            },
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
    const install_gui_app = b.addInstallArtifact(artifact, .{
        .dest_dir = .{ .override = .{ .custom = bundle_subpath } },
        .dest_sub_path = artifact.name,
    });
    return install_gui_app;
}

// Creates the install step for generating and installing the bundle's Info.plist.
pub fn addInstallInfoPlist(
    juceaide: Juceaide,
    config: ProjectConfig,
    kind: ProductKind,
) *std.Build.Step.InstallFile {
    const b = juceaide.artifact.root_module.owner;
    const plist_cmd = b.addRunArtifact(juceaide.artifact);
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
    // Suppress the "JUCE vX.X.X" banner to keep the build logs clean.
    _ = pkginfo_cmd.captureStdErr();

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

pub fn generateInfoText(b: *std.Build, config: ProjectConfig) !std.Build.LazyPath {
    var buf: std.ArrayList(u8) = .empty;

    try appendRecord(&buf, b.allocator, "EXECUTABLE_NAME", config.product_name);
    try appendRecord(&buf, b.allocator, "VERSION", config.version);
    try appendRecord(&buf, b.allocator, "BUILD_VERSION", config.build_version);
    try appendRecord(&buf, b.allocator, "BUNDLE_ID", config.bundle_id);

    // TODO: append more records
    // ...

    const wf = b.addWriteFiles();
    _ = wf.add("Info.txt", buf.items);

    return wf.getDirectory();
}

fn appendRecord(buf: *std.ArrayList(u8), gpa: std.mem.Allocator, key: []const u8, value: []const u8) !void {
    const rs: u8 = 30; // Record Separator
    const us: u8 = 31; // Unit Separator

    try buf.appendSlice(gpa, key);
    try buf.append(gpa, us);
    try buf.appendSlice(gpa, value);
    try buf.append(gpa, rs);
}
