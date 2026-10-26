const std = @import("std");
const juzi = @import("juzi");
const zon = @import("build.zig.zon");

pub fn build(b: *std.Build) void {
    var plugin = juzi.Plugin.init(b, .{
        .juzi = b.dependency("juzi", .{}),
        .config = .{
            .product_name = "Audio Plugin Example",
            .version = zon.version,
            .bundle_id = "com.example.AudioPluginExample",
            .plugin_manufacturer_code = "Juzi",
            .plugin_code = "Juzi",
            .formats = &.{ .vst3, .au, .standalone },
        },
        .juce_modules = &.{juzi.modules.juce_audio_utils},
        .cxx_standard = .cxx20,
    });
    plugin.root_module.addCSourceFiles(.{
        .root = b.path("src"),
        .files = &.{
            "PluginEditor.cpp",
            "PluginProcessor.cpp",
        },
        .flags = &.{
            "--std=c++20",
            "-fvisibility=hidden",
            "-fvisibility-inlines-hidden",
        },
    });
    plugin.root_module.addCMacro("JUCE_VST3_CAN_REPLACE_VST2", "0");
    plugin.root_module.addCMacro("JUCE_WEB_BROWSER", "0");
    plugin.root_module.addCMacro("JUCE_USE_CURL", "0");

    // Configure embedded binary data here, similar to JUCE's add_binary_data.
    // plugin.addBinaryData(.{
    //     .namespace = "JuziBinary",
    //     .header_name = "JuziBinary",
    //     .files = &.{ "res/juzi.wav", "res/juzi.icon" },
    // });

    plugin.finalize();

    var steps_it = plugin.install_steps.valueIterator();
    while (steps_it.next()) |step| {
        b.getInstallStep().dependOn(step.*);
    }
}
