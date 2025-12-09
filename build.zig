const std = @import("std");
pub const ProjectConfig = @import("src/ProjectConfig.zig");
pub const Setup = @import("src/Setup.zig");
pub const modules = @import("src/modules.zig");

pub fn build(b: *std.Build) void {
    _ = b;
}
