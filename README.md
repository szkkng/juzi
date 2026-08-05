# juzi

Build JUCE audio plugins using the Zig build system.

## Current limitations

- Supported OS: macOS, Linux
- Supported formats: VST3, AU, Standalone

## Requirements

- Zig v0.16.0

## Dependencies

- JUCE v9.0.0 (automatically fetched by the Zig build system)

## Usage

Initialize a Zig build project if you haven't already:

```bash
zig init
```

Download and add juzi as a dependency by running the following command in your project root:

```bash
zig fetch --save git+https://codeberg.org/kengo/juzi
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

    // Initialize the plugin.
    var plugin = juzi.Plugin.init(b, .{
        .juzi = b.dependency("juzi", .{}),
        .target = target,
        .optimize = optimize,
        .config = .{
            .product_name = "JuziPlugin",
            .version = zon.version,
            .bundle_id = "com.example.juzi",
            .plugin_manufacturer_code = "Juzi",
            .plugin_code = "Juzi",
            .formats = &.{ .vst3, .au, .standalone },
        },
        .juce_modules = &.{juzi.modules.juce_audio_utils},
        .cxx_standard = .cxx20,
    });

    // Add the plugin's C++ source files.
    plugin.root_module.addCSourceFiles(.{
        .root = b.path("src"),
        .files = &.{
            "PluginEditor.cpp",
            "PluginProcessor.cpp",
        },
        .flags = &.{
            "-Wall",
            "-Wextra",
            "-Werror",
        },
    });

    // Configure JUCE-related preprocessor macros.
    plugin.addJuceMacro("JUCE_VST3_CAN_REPLACE_VST2", "0");
    plugin.addJuceMacro("JUCE_WEB_BROWSER", "0");
    plugin.addJuceMacro("JUCE_USE_CURL", "0");

    // Finalize the plugin after all configuration is complete.
    const result = plugin.finalize();

    // Add the collected install steps as dependencies of the top-level install step.
    var steps_it = result.install_steps.valueIterator();
    while (steps_it.next()) |step| {
        b.getInstallStep().dependOn(step.*);
    }
}
```

To build:

```bash
zig build -Doptimize=ReleaseFast
```

For audio plugin projects, you can build a specific format and install it:

```bash
zig build vst3 -Doptimize=ReleaseFast -p ~/Library/Audio/Plug-Ins/VST3
```

You can list all available steps by running:

```bash
zig build -l
```

## Generating compile_commands.json

Zig doesn't currently support generating `compile_commands.json`.  
A common solution is to use [the-argus/zig-compile-commands](https://github.com/the-argus/zig-compile-commands).  
See the example projects in this repo for how to use it with juzi.

## License

MIT.  
JUCE is licensed separately: https://github.com/juce-framework/JUCE
