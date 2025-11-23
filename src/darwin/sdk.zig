const std = @import("std");

pub fn addPaths(b: *std.Build, m: *std.Build.Module) void {
    const sdkPath = std.zig.system.darwin.getSdk(b.allocator, &m.resolved_target.?.result) orelse
        @panic("apple sdk not found");
    m.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ sdkPath, "/System/Library/Frameworks" }) });
    m.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdkPath, "/usr/include" }) });
    m.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdkPath, "/usr/lib" }) });
}
