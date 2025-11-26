const std = @import("std");
const juzi = @import("juzi");
const zon = @import("build.zig.zon");
const zcc = @import("compile_commands");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const config = juzi.ProjectConfig.create(b, .{
        .product_name = "Audio Plugin Example",
        .version = zon.version,
        .bundle_id = "com.example.AudioPluginExample",
        .plugin_manufacturer_code = "Juzi",
        .plugin_code = "Juzi",
        .formats = &.{ .vst3, .au, .standalone },
    });

    const module = b.createModule(.{ .target = target, .optimize = optimize });
    module.addCSourceFiles(.{
        .root = b.path("src"),
        .files = &.{
            "PluginEditor.cpp",
            "PluginProcessor.cpp",
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
    juzi_setup.addJuceMacro("JUCE_VST3_CAN_REPLACE_VST2", "0");
    juzi_setup.addJuceMacro("JUCE_WEB_BROWSER", "0");
    juzi_setup.addJuceMacro("JUCE_USE_CURL", "0");

    // Configure embedded binary data here, similar to JUCE's add_binary_data.
    // juzi_setup.addBinaryData(.{
    //     .namespace = "JuziBinary",
    //     .header_name = "JuziBinary",
    //     .files = &.{ "res/juzi.wav", "res/juzi.icon" },
    // });

    const plugin = juzi_setup.addPlugin(.{
        .juce_modules = &.{.juce_audio_utils},
        .config = config,
    });

    var steps_it = plugin.install_steps.valueIterator();
    while (steps_it.next()) |step| {
        b.getInstallStep().dependOn(step.*);
    }

    // Create a step that generates compile_commands.json.
    // Running `zig build cdb` will write the file to the project root.
    var targets = std.ArrayList(*std.Build.Step.Compile).empty;
    var artifacts_it = plugin.artifacts.valueIterator();
    while (artifacts_it.next()) |artifact| {
        targets.append(b.allocator, artifact.*) catch @panic("OOM");
    }
    const cdb_step = zcc.createStep(b, "cdb", targets.toOwnedSlice(b.allocator) catch @panic("OOM"));
    _ = cdb_step;

    // If you configure binary data above, make the cdb step depend on the
    // generated BinaryData target. Otherwise, compile_commands.json
    // generation will fail.
    // if (plugin.binary_data) |bd| {
    //     cdb_step.dependOn(&bd.step);
    // }
}
