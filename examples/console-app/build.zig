const std = @import("std");
const juzi = @import("juzi");
const zon = @import("build.zig.zon");

const config = juzi.utils.ProjectConfig{
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
    module.addCMacro("JUCE_WEB_BROWSER", "0");
    module.addCMacro("JUCE_USE_CURL", "0");
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
    const console_app = juzi.utils.addConsoleApp(juzi_dep, .{
        .root_module = module,
        .juce_modules = &.{"juce_core"},
        .config = config,
    });
    b.installArtifact(console_app);

    const run_step = b.step("run", "Run the app");
    const gui_app_run = b.addRunArtifact(console_app);
    gui_app_run.step.dependOn(b.getInstallStep());
    run_step.dependOn(&gui_app_run.step);
}
