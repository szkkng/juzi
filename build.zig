const std = @import("std");
pub const Setup = @import("src/Setup.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    inline for (@import("src/root.zig").modules) |m| {
        _ = m.addModule(b, target, optimize);
    }
}
