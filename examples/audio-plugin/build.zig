const std = @import("std");
const juzi = @import("juzi");
const zon = @import("build.zig.zon");

const config = juzi.Setup.ProjectConfig{
    .product_name = "JuceZbs",
    .version = zon.version,
    .bundle_id = "com.example.jucezbs",
    .plugin_manufacturer_code = "Jzbs",
    .plugin_code = "Jzbs",
    .formats = &.{ .vst3, .standalone },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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

    const plugin = juzi_setup.addPlugin(.{
        .juce_modules = &.{.juce_audio_utils},
        .config = config,
    });

    var steps_it = plugin.install_steps.valueIterator();
    while (steps_it.next()) |step| {
        b.getInstallStep().dependOn(step.*);
    }
}
