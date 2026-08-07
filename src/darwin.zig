const std = @import("std");
const Config = @import("plugin/Config.zig");
const Format = @import("plugin/format.zig").Format;
const Juceaide = @import("Juceaide.zig");
const setup = @import("setup.zig");

pub fn addSdkPaths(b: *std.Build, m: *std.Build.Module) void {
    const sdkPath = std.zig.system.darwin.getSdk(b.allocator, b.graph.io, &m.resolved_target.?.result) orelse
        @panic("apple sdk not found");
    m.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ sdkPath, "/System/Library/Frameworks" }) });
    m.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdkPath, "/usr/include" }) });
    m.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdkPath, "/usr/lib" }) });
}

pub fn addAdhocCodesign(
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
    _ = adhoc_sign_cmd.captureStdErr(.{});
    return adhoc_sign_cmd;
}

// Describes the final product kind (app or plugin) and, if a plugin, its format.
const ProductKind = union(enum) {
    console_app,
    gui_app,
    plugin: Format,

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
    info_text_file: std.Build.LazyPath,
    config: Config,
    kind: ProductKind,
) *std.Build.Step.InstallFile {
    const b = juceaide.artifact.root_module.owner;
    const plist_cmd = b.addRunArtifact(juceaide.artifact);
    plist_cmd.addArgs(&.{
        "plist",
        kind.juceaideIdentifier(),
    });
    plist_cmd.addFileArg(info_text_file);
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
    juce: *std.Build.Dependency,
    product_name: []const u8,
    product_kind: ProductKind,
) *std.Build.Step.InstallFile {
    const wf = b.addWriteFiles();
    const nib_file_name = "RecentFilesMenuTemplate.nib";
    const nib_file_source = b.fmt("extras/Build/CMake/{s}", .{nib_file_name});
    const nib_file_path = wf.addCopyFile(juce.path(nib_file_source), nib_file_name);
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
