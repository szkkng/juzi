# juzi

WIP: [JUCE](https://github.com/juce-framework/JUCE) using the [Zig](https://ziglang.org/) build system

Current limitations:

- Only macOS builds are supported.
- Plugin formats are limited to VST3 and Standalone.
- Only the JUCE modules required for the included examples are implemented.
- Many configuration fields are still missing.

## Usage

Initialize a Zig build project if you haven't already:

```bash
zig init
```

Download and add juzi as a dependency by running the following command in your project root:

```bash
zig fetch --save git+https://github.com/szkkng/juzi.git
```

Then, configure your `build.zig` to use juzi.  
Here is an example configuration for an audio plugin project:

```zig
const std = @import("std");
const zon = @import("build.zig.zon");
// Import juzi build utilities.
const juzi = @import("juzi");

// Define project configuration.
const config = juzi.utils.ProjectConfig{
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

    // Create the module for the plugin's C++ source files.
    const module = b.createModule(.{ .target = target, .optimize = optimize });
    module.addCMacro("JUCE_VST3_CAN_REPLACE_VST2", "0");
    module.addCMacro("JUCE_WEB_BROWSER", "0");
    module.addCMacro("JUCE_USE_CURL", "0");
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

    // Add juzi as a dependency.
    const juzi_dep = b.dependency("juzi", .{ .target = target, .optimize = optimize });
    // Configure the plugin and collect install steps for the selected plugin formats.
    const plugin = juzi.utils.addPlugin(juzi_dep, .{
        .root_module = module,
        .juce_modules = &.{"juce_audio_utils"},
        .config = config,
    });

    // Add the collected install steps as dependencies of the top-level install step.
    var steps_it = plugin.install_steps.valueIterator();
    while (steps_it.next()) |step| {
        b.getInstallStep().dependOn(step.*);
    }
}
```

To build:

```bash
zig build
```

## Motivation

- To better understand both the JUCE CMake build system and Zig's build system.
- Just for fun.
