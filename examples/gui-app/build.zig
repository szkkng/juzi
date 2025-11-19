const std = @import("std");
const juzi = @import("juzi");
const zon = @import("build.zig.zon");

const config = juzi.Setup.ProjectConfig{
    .product_name = "GUI App Example",
    .version = zon.version,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });
    module.addCSourceFiles(.{
        .root = b.path("src"),
        .files = &.{
            "Main.cpp",
            "MainComponent.cpp",
        },
        .flags = &.{
            "--std=c++20",
            "-Wall",
            "-Wextra",
            "-Werror",
        },
    });

    const juzi_dep = b.dependency("juzi", .{});
    const juzi_setup = juzi.Setup.init(juzi_dep, module);
    const gui_app = juzi_setup.addGuiApp(.{
        .juce_modules = &.{"juce_gui_extra"},
        .config = config,
        .flags = &.{
            "-DJUCE_WEB_BROWSER=0",
            "-DJUCE_USE_CURL=0",
            b.fmt("-DJUCE_APPLICATION_NAME_STRING=\"{s}\"", .{"GUI App Example"}),
            b.fmt("-DJUCE_APPLICATION_VERSION_STRING=\"{s}\"", .{zon.version}),
        },
    });
    b.getInstallStep().dependOn(&gui_app.step);

    const run_step = b.step("run", "Run the app");
    const gui_app_run = b.addRunArtifact(gui_app.artifact);
    gui_app_run.step.dependOn(&gui_app.step);
    run_step.dependOn(&gui_app_run.step);
}
