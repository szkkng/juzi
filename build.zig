const std = @import("std");
const root = @import("src/root.zig");

pub const Plugin = root.Plugin;
pub const Config = root.Config;
pub const JuceModule = root.JuceModule;
pub const modules = root.modules;

pub fn build(b: *std.Build) void {
    const docs_step = b.step("docs", "Emit docs");
    const docs_obj = b.addObject(.{
        .name = "root",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = b.standardTargetOptions(.{}),
        }),
    });
    const docs_install = b.addInstallDirectory(.{
        .install_dir = .prefix,
        .install_subdir = "docs",
        .source_dir = docs_obj.getEmittedDocs(),
    });
    docs_step.dependOn(&docs_install.step);
}
