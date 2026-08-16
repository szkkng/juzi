const std = @import("std");

// Recursively copies a directory, replacing any existing destination directory with the same name.
pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();

    const args = try init.minimal.args.toSlice(arena);
    if (args.len != 3)
        @panic("expected source and destination directories");

    const arg_src_dir = args[1];
    const arg_dest_dir = args[2];

    const src_dir = try std.Io.Dir.openDirAbsolute(
        init.io,
        arg_src_dir,
        .{ .iterate = true },
    );
    defer src_dir.close(init.io);

    const dest_dir = b: {
        const basename = std.fs.path.basename(arg_src_dir);
        const dest = std.fs.path.join(arena, &.{ arg_dest_dir, basename }) catch @panic("OOM");
        std.Io.Dir.createDirAbsolute(init.io, dest, .default_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;

            // Remove the existing destination directory before copying.
            const dest_dir = try std.Io.Dir.openDirAbsolute(init.io, arg_dest_dir, .{});
            defer dest_dir.close(init.io);
            try dest_dir.deleteTree(init.io, basename);
            try std.Io.Dir.createDirAbsolute(init.io, dest, .default_dir);
        };
        break :b try std.Io.Dir.openDirAbsolute(init.io, dest, .{});
    };
    defer dest_dir.close(init.io);

    var walker = try src_dir.walk(arena);
    defer walker.deinit();

    while (try walker.next(init.io)) |entry| {
        switch (entry.kind) {
            .file => {
                try entry.dir.copyFile(entry.basename, dest_dir, entry.path, init.io, .{});
            },
            .directory => {
                try dest_dir.createDirPath(init.io, entry.path);
            },
            else => {},
        }
    }
}
