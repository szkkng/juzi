const std = @import("std");
const juzi = @import("juzi");
const zon = @import("build.zig.zon");
const zcc = @import("compile_commands");

const config = juzi.Setup.ProjectConfig{
    .product_name = "Console App Example",
    .version = zon.version,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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

    const juzi_dep = b.dependency("juzi", .{ .target = target, .optimize = optimize });
    var juzi_setup = juzi.Setup.init(juzi_dep, module);
    juzi_setup.addJuceMacro("JUCE_WEB_BROWSER", "0");
    juzi_setup.addJuceMacro("JUCE_USE_CURL", "0");

    const console_app = juzi_setup.addConsoleApp(.{
        .juce_modules = &.{.juce_core},
        .config = config,
    });
    b.installArtifact(console_app);

    const run_step = b.step("run", "Run the app");
    const console_app_run = b.addRunArtifact(console_app);
    console_app_run.step.dependOn(b.getInstallStep());
    run_step.dependOn(&console_app_run.step);

    var targets = std.ArrayList(*std.Build.Step.Compile).empty;
    targets.append(b.allocator, console_app) catch @panic("OOM");
    _ = zcc.createStep(b, "cdb", targets.toOwnedSlice(b.allocator) catch @panic("OOM"));
}
