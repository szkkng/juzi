const std = @import("std");
const juzi = @import("juzi");
const zon = @import("build.zig.zon");
const zcc = @import("compile_commands");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const config = juzi.ProjectConfig.create(b, .{
        .product_name = "Console App Example",
        .version = zon.version,
        .bundle_id = "com.example.ConsoleAppExample",
    });

    const module = b.createModule(.{
        .target = target,
        .optimize = optimize,
    });
    module.addCSourceFiles(.{
        .root = b.path("src"),
        .files = &.{
            "Main.cpp",
        },
        .flags = &.{
            "--std=c++20",
            "-Wall",
            "-Wextra",
            "-Werror",
        },
    });

    const juzi_dep = b.dependency("juzi", .{});
    var juzi_setup = juzi.Setup.init(juzi_dep, module);
    juzi_setup.addJuceMacro("JUCE_WEB_BROWSER", "0");
    juzi_setup.addJuceMacro("JUCE_USE_CURL", "0");

    // Configure embedded binary data here, similar to JUCE's add_binary_data.
    // juzi_setup.addBinaryData(.{
    //     .namespace = "JuziBinary",
    //     .header_name = "JuziBinary",
    //     .files = &.{ "res/juzi.wav", "res/juzi.icon" },
    // });

    const console_app = juzi_setup.addConsoleApp(.{
        .juce_modules = &.{juzi.modules.juce_core},
        .config = config,
    });
    b.installArtifact(console_app.artifact);

    const run_step = b.step("run", "Run the app");
    const console_app_run = b.addRunArtifact(console_app.artifact);
    console_app_run.step.dependOn(b.getInstallStep());
    run_step.dependOn(&console_app_run.step);

    // Create a step that generates compile_commands.json.
    // Running `zig build cdb` will write the file to the project root.
    var targets = std.ArrayList(*std.Build.Step.Compile).empty;
    targets.append(b.allocator, console_app.artifact) catch @panic("OOM");
    const cdb_step = zcc.createStep(b, "cdb", targets.toOwnedSlice(b.allocator) catch @panic("OOM"));
    _ = cdb_step;

    // If you configure binary data above, make the cdb step depend on the
    // generated BinaryData target. Otherwise, compile_commands.json
    // generation will fail.
    // if (console_app.binary_data) |bd| {
    //     cdb_step.dependOn(&bd.step);
    // }
}
