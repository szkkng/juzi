const std = @import("std");
const CxxStandard = @import("setup.zig").CxxStandard;
const JuceModule = @This();

name: []const u8,
deps: []const JuceModule,
configure: *const fn (root_module: *std.Build.Module, ctx: BuildContext) void,

pub const BuildContext = struct {
    builder: *std.Build,
    juce: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    cxx_standard: CxxStandard,

    pub fn cFlags(
        self: BuildContext,
        extra: []const []const u8,
    ) []const []const u8 {
        return std.mem.concat(
            self.builder.allocator,
            []const u8,
            &.{
                &.{"-fvisibility=hidden"},
                extra,
            },
        ) catch @panic("OOM");
    }

    pub fn cxxFlags(
        self: BuildContext,
        extra: []const []const u8,
    ) []const []const u8 {
        return std.mem.concat(
            self.builder.allocator,
            []const u8,
            &.{
                &.{self.cxx_standard.flag()},
                &.{
                    "-fvisibility=hidden",
                    "-fvisibility-inlines-hidden",
                },
                extra,
            },
        ) catch @panic("OOM");
    }
};
