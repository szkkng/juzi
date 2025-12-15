const std = @import("std");
const Juceaide = @import("Juceaide.zig");

pub const CreateOptions = struct {
    namespace: []const u8 = "BinaryData",
    header_name: []const u8 = "BinaryData",
    files: []const []const u8,
};

pub fn create(juceaide: Juceaide, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, options: CreateOptions) *std.Build.Step.Compile {
    const b = juceaide.artifact.root_module.owner;

    const binary_data_lib = b.addLibrary(.{
        .name = "binary_data",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
    });

    const input_list_file = addInputFileList(b, options.files);

    var binary_data_files = std.ArrayList([]const u8).empty;
    for (options.files, 0..) |_, i| {
        binary_data_files.append(
            b.allocator,
            b.fmt("{s}{d}.cpp", .{ "BinaryData", i + 1 }),
        ) catch @panic("OOM");
    }

    const output_dir = input_list_file.dirname();
    const binary_data_cmd = b.addRunArtifact(juceaide.artifact);
    binary_data_cmd.setCwd(output_dir);

    binary_data_cmd.addArgs(&.{
        "binarydata",
        options.namespace,
        b.fmt("{s}.h", .{options.header_name}),
    });
    binary_data_cmd.addDirectoryArg(output_dir);
    binary_data_cmd.addFileArg(input_list_file);

    binary_data_lib.root_module.addCSourceFiles(.{
        .root = output_dir,
        .files = binary_data_files.items,
    });
    binary_data_lib.root_module.addIncludePath(output_dir);
    binary_data_lib.step.dependOn(&binary_data_cmd.step);

    return binary_data_lib;
}

fn addInputFileList(
    b: *std.Build,
    input_files: []const []const u8,
) std.Build.LazyPath {
    const wf = b.addWriteFiles();
    const input_file_name = "input_file_list";

    for (input_files) |file| {
        _ = wf.addCopyFile(b.path(file), file);
    }

    const path = wf.add(input_file_name, std.mem.join(b.allocator, "\n", input_files) catch @panic("OOM"));
    return path;
}
