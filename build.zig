const std = @import("std");
pub const ProjectConfig = @import("src/ProjectConfig.zig");
pub const Plugin = @import("src/Plugin.zig");
pub const modules = @import("src/modules.zig");

pub fn build(b: *std.Build) void {
    _ = b;
}
