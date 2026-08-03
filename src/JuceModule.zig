const std = @import("std");
const JuceModule = @This();

name: []const u8,
deps: []const JuceModule,
create: *const fn (ctx: BuildContext) *std.Build.Module,

pub const BuildContext = struct {
    builder: *std.Build,
    juce: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    juce_required_flags: RequiredFlags,
};

/// Required compiler flags resolved by `Setup` for sources that include JUCE headers.
/// They contain the JUCE preprocessor definitions and language-specific compiler options.
/// In your `create` callback, pass the matching field to `.flags`
/// when calling `addCSourceFile` or `addCSourceFiles`.
pub const RequiredFlags = struct {
    /// Flags for C sources.
    c: []const []const u8,
    /// Flags for C++ and Objective-C++ sources.
    cxx: []const []const u8,
};
