const std = @import("std");
const juzi = @import("juzi");
const zon = @import("build.zig.zon");
const zcc = @import("compile_commands");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const config = juzi.ProjectConfig.create(b, .{
        .product_name = "GUI App Example",
        .version = zon.version,
        .bundle_id = "com.example.GuiAppExample",
    });

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

    const juzi_dep = b.dependency("juzi", .{ .target = target, .optimize = optimize });
    var juzi_setup = juzi.Setup.init(juzi_dep, module);
    juzi_setup.addJuceMacro("JUCE_WEB_BROWSER", "0");
    juzi_setup.addJuceMacro("JUCE_USE_CURL", "0");
    juzi_setup.addJuceMacro(
        "JUCE_APPLICATION_NAME_STRING",
        b.fmt("\"{s}\"", .{"GUI App Example"}),
    );
    juzi_setup.addJuceMacro(
        "JUCE_APPLICATION_VERSION_STRING",
        b.fmt("\"{s}\"", .{zon.version}),
    );

    // Configure embedded binary data here, similar to JUCE's add_binary_data.
    // juzi_setup.addBinaryData(.{
    //     .namespace = "JuziBinary",
    //     .header_name = "JuziBinary",
    //     .files = &.{ "res/juzi.wav", "res/juzi.icon" },
    // });

    const gui_app = juzi_setup.addGuiApp(.{
        .juce_modules = &.{.juce_gui_extra},
        .config = config,
    });
    b.getInstallStep().dependOn(gui_app.install_step);

    const run_step = b.step("run", "Run the app");
    const gui_app_run = b.addRunArtifact(gui_app.artifact);
    gui_app_run.step.dependOn(gui_app.install_step);
    run_step.dependOn(&gui_app_run.step);

    // Create a step that generates compile_commands.json.
    // Running `zig build cdb` will write the file to the project root.
    var targets = std.ArrayList(*std.Build.Step.Compile).empty;
    targets.append(b.allocator, gui_app.artifact) catch @panic("OOM");
    const cdb_step = zcc.createStep(b, "cdb", targets.toOwnedSlice(b.allocator) catch @panic("OOM"));
    _ = cdb_step;

    // If you configure binary data above, make the cdb step depend on the
    // generated BinaryData target. Otherwise, compile_commands.json
    // generation will fail.
    // if (gui_app.binary_data) |bd| {
    //     cdb_step.dependOn(&bd.step);
    // }
}
