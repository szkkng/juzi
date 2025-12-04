# juzi

Build JUCE projects using the Zig build system.
Currently WIP.

## Limitations

- Windows is not supported due to Zig [issue](https://github.com/ziglang/zig/issues/18685).
- Formats: VST3, AU, Standalone.
- Only the JUCE modules required to build the examples are supported.

## Requirements

- Zig v0.15.2

## Dependencies

- JUCE v8.0.11 (automatically fetched by the Zig build system)

## Usage

Initialize a Zig build project if you haven't already:

```bash
zig init
```

Download and add juzi as a dependency by running the following command in your project root:

```bash
zig fetch --save git+https://github.com/szkkng/juzi
```

Then, configure your `build.zig` to use juzi.  
Here is an example configuration for an audio plugin project:

```zig
const std = @import("std");
const zon = @import("build.zig.zon");
// Import juzi build utilities.
const juzi = @import("juzi");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create project configuration.
    const config = juzi.ProjectConfig.create(b, .{
        .product_name = "JuziPlugin",
        .version = zon.version,
        .bundle_id = "com.example.juzi",
        .plugin_manufacturer_code = "Juzi",
        .plugin_code = "Juzi",
        .formats = &.{ .vst3, .au, .standalone },
    });

    // Create the module for the plugin's C++ source files.
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

    // Initialize juzi setup using this module and the juzi dependency.
    const juzi_dep = b.dependency("juzi", .{ .target = target, .optimize = optimize });
    var juzi_setup = juzi.Setup.init(juzi_dep, module);

    // Configure JUCE-related preprocessor macros.
    juzi_setup.addJuceMacro("JUCE_VST3_CAN_REPLACE_VST2", "0");
    juzi_setup.addJuceMacro("JUCE_WEB_BROWSER", "0");
    juzi_setup.addJuceMacro("JUCE_USE_CURL", "0");

    // Configure embedded binary data here, similar to JUCE's add_binary_data.
    // juzi_setup.addBinaryData(.{
    //     .namespace = "JuziBinary",
    //     .header_name = "JuziBinary",
    //     .files = &.{ "res/juzi.wav", "res/juzi.icon" },
    // });

    // After configuring juzi, add plugin targets for the selected formats.
    const plugin = juzi_setup.addPlugin(.{
        .juce_modules = &.{.juce_audio_utils},
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
zig build -Doptimize=ReleaseFast
```

## Generating compile_commands.json

Zig doesn't currently support generating `compile_commands.json`.  
A common solution is to use [the-argus/zig-compile-commands](https://github.com/the-argus/zig-compile-commands).  
See the example projects in this repo for how to use it with juzi.

## Motivation

- To better understand both the JUCE CMake build system and Zig's build system.
- Just for fun.

## License

MIT.  
JUCE is licensed separately: https://github.com/juce-framework/JUCE
