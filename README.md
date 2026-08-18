# juzi

Build JUCE audio plugins using the Zig build system.

## Status

Under active development, expect breaking changes.

- Supported formats: VST3, AUv2, Standalone
- Supported platforms: macOS, Linux, Windows

## Requirements

- [Zig](https://ziglang.org/download/) 0.16.0
- [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads) (Windows only)
- [JUCE Linux dependencies](https://github.com/juce-framework/JUCE/blob/master/docs/Linux%20Dependencies.md#packages) (Linux only)

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
            "--std=c++20",
            "-fvisibility=hidden",
            "-fvisibility-inlines-hidden",
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

## Using custom JUCE modules

You can integrate your own or third-party JUCE modules simply by defining a `juzi.JuceModule`.

Here is a minimal example:

```zig
const juzi = @import("juzi");

pub const my_juce_module: juzi.JuceModule = .{
    // A unique name for this module.
    .name = "my_juce_module",
    // Other modules this module depends on.
    .deps = &.{juzi.modules.juce_core},
    // A function that adds sources and build settings to the root module.
    .configure = struct {
        fn f(root_module: *std.Build.Module, ctx: juzi.JuceModule.BuildContext) void {
            root_module.addCSourceFiles(.{
                .root = ctx.builder.path("lib/my_juce_module"),
                .files = &.{"my_juce_module.cpp"},
                .flags = ctx.cxxFlags(&.{}),
            });
        }
    }.f,
};
```

Then add it to the `juce_modules` field of `Plugin.init`:

```zig
pub fn build(b: *std.Build) void {
    var plugin = juzi.Plugin.init(b, .{
        // ...
        .juce_modules = &.{
            // ...
            my_juce_module,
        },
    });
}
```

For reference, see how juzi's JUCE modules are defined in [`src/modules`](./src/modules).

## Generating compile_commands.json

Zig doesn't currently support generating `compile_commands.json`.  
A common solution is to use [the-argus/zig-compile-commands](https://github.com/the-argus/zig-compile-commands).  
See the example projects in this repo for how to use it with juzi.

## License

MIT.  
JUCE is licensed separately: https://github.com/juce-framework/JUCE
