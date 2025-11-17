# juzi

WIP: [JUCE](https://github.com/juce-framework/JUCE) using the [Zig](https://ziglang.org/) build system

Currently, only basic macOS builds of console apps, GUI apps, and audio plugins
(VST3 and standalone) are supported, and only some JUCE modules have been
implemented so far (currently just enough to build the included examples). The
examples build and run, but many configuration fields are still missing, and
their behavior hasn’t been fully verified yet.

## Usage

Initialize a Zig build project if you haven't already:

```bash
zig init
```

Fetch the dependency and add it to your `build.zig.zon`:

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
