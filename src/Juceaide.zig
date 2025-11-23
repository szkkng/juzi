const std = @import("std");
const Juceaide = @This();

upstream: *std.Build.Dependency,
target: std.Build.ResolvedTarget,
optimize: std.builtin.OptimizeMode,
artifact: *std.Build.Step.Compile,
juce_modules_lib: *std.Build.Step.Compile,

pub const InitOptions = struct {
    upstream: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    juce_modules_lib: *std.Build.Step.Compile,
};

pub fn create(
    b: *std.Build,
    options: InitOptions,
) Juceaide {
    const juceaide = b.addExecutable(.{
        .name = "juceaide",
        .root_module = b.createModule(.{
            .target = options.target,
            .optimize = options.optimize,
            .link_libcpp = true,
        }),
    });
    juceaide.root_module.linkLibrary(options.juce_modules_lib);
    juceaide.root_module.addIncludePath(options.upstream.path("modules"));
    juceaide.root_module.addIncludePath(options.upstream.path("extras/Build"));
    juceaide.root_module.addCSourceFiles(.{
        .root = options.upstream.path("extras/Build/juceaide"),
        .files = &.{"Main.cpp"},
    });

    return .{
        .upstream = options.upstream,
        .target = options.target,
        .optimize = options.optimize,
        .juce_modules_lib = options.juce_modules_lib,
        .artifact = juceaide,
    };
}

pub const BinaryData = struct {
    namespace: []const u8 = "BinaryData",
    header_name: []const u8 = "BinaryData",
    files: []const []const u8,
};

pub fn addBinaryData(
    self: Juceaide,
    b: *std.Build,
    binary_data: BinaryData,
) *std.Build.Step.Compile {
    const binary_data_lib = b.addLibrary(.{
        .name = "binary_data",
        .root_module = b.createModule(.{
            .target = self.target,
            .optimize = self.optimize,
            .link_libcpp = true,
        }),
    });

    const input_list_file = addInputFileList(b, binary_data.files);

    var binary_data_files = std.ArrayList([]const u8).empty;
    for (binary_data.files, 0..) |_, i| {
        binary_data_files.append(
            b.allocator,
            b.fmt("{s}{d}.cpp", .{ "BinaryData", i + 1 }),
        ) catch @panic("OOM");
    }

    const output_dir = input_list_file.dirname();
    const binary_data_cmd = b.addRunArtifact(self.artifact);
    binary_data_cmd.setCwd(output_dir);

    binary_data_cmd.addArgs(&.{
        "binarydata",
        binary_data.namespace,
        b.fmt("{s}.h", .{binary_data.header_name}),
    });
    // The fourth juceaide argument (the BinaryData output directory) is currently
    // passed as a relative path, which triggers the assertion
    // “JUCE Assertion failure in juce_File.cpp:219”. The build still works, so
    // the output is suppressed here just to keep the logs clean.
    // Is there a good way to provide an absolute path instead?
    binary_data_cmd.addDirectoryArg(output_dir);
    binary_data_cmd.addFileArg(input_list_file);
    binary_data_cmd.has_side_effects = true;
    _ = binary_data_cmd.captureStdErr();

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
