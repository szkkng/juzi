const std = @import("std");
pub const ProjectConfig = @import("src/ProjectConfig.zig");
pub const Setup = @import("src/Setup.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});

    inline for (@import("src/modules.zig").modules) |m| {
        _ = m.addModule(b, upstream, target, optimize);
    }
}
