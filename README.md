# juzi

Build JUCE audio plugins using the Zig build system.

## Status

Under active development, expect breaking changes.

Supports VST3, AUv2, and Standalone plugins on macOS, Linux, and Windows.

## Requirements

- Zig v0.16.0
- Visual Studio Build Tools (Windows only)

## Dependencies

- JUCE v9.0.1 (automatically fetched by the Zig build system)

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
Here is a minimal example:

```zig
const std = @import("std");
const zon = @import("build.zig.zon");
// Import juzi build utilities.
const juzi = @import("juzi");

pub fn build(b: *std.Build) void {
    // Initialize the plugin.
    var plugin = juzi.Plugin.init(b, .{
        .juzi = b.dependency("juzi", .{}),
        .config = .{
            .product_name = "JuziPlugin",
            .version = zon.version,
            .bundle_id = "com.example.juzi",
            .plugin_manufacturer_code = "Juzi",
            .plugin_code = "Juzi",
            .formats = &.{ .vst3, .au, .standalone },
        },
        .juce_modules = &.{juzi.modules.juce_audio_utils},
    });

    // Add the plugin's C++ source files.
    plugin.root_module.addCSourceFiles(.{
        .root = b.path("src"),
        .files = &.{
            "PluginEditor.cpp",
            "PluginProcessor.cpp",
        },
    });

    // Configure JUCE macros.
    plugin.root_module.addCMacro("JUCE_VST3_CAN_REPLACE_VST2", "0");
    plugin.root_module.addCMacro("JUCE_WEB_BROWSER", "0");
    plugin.root_module.addCMacro("JUCE_USE_CURL", "0");

    // Finalize the plugin after all configuration is complete.
    plugin.finalize();

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

For release builds, add `-Doptimize=ReleaseFast`.

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
