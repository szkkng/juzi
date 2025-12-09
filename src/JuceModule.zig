const std = @import("std");
pub const JuceModule = @This();

pub const BuildContext = struct {
    builder: *std.Build,
    visited: *std.StringArrayHashMapUnmanaged(*std.Build.Module),
    upstream: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

name: []const u8,
createModule: *const fn (ctx: BuildContext) *std.Build.Module,

pub fn init(
    comptime name: []const u8,
    comptime createModule: fn (ctx: BuildContext) *std.Build.Module,
) JuceModule {
    return .{
        .name = name,
        .createModule = createModule,
    };
}
