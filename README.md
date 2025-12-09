# juzi

Build JUCE projects using the Zig build system.  
Currently WIP.

## Limitations

- Windows is not supported due to Zig [issue](https://github.com/ziglang/zig/issues/18685).
- Formats: VST3, AU, Standalone.

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
    const juzi_dep = b.dependency("juzi", .{});
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
        .juce_modules = &.{juzi.modules.juce_audio_utils},
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

For audio plugin projects, you can build a specific format and install it:

```bash
zig build vst3 -Doptimize=ReleaseFast -p ~/Library/Audio/Plug-Ins/VST3
```

The vst3 step becomes available when you specify the format in your ProjectConfig, for example:

```zig
const config = juzi.ProjectConfig.create(b, .{
// ...
    .formats = &.{ .vst3 },
});
```

You can list all available steps by running:

```bash
zig build -l
```

## ProjectConfig fields

These fields correspond to the arguments used in JUCE’s `juce_add_<target>` functions.
Refer to the [JUCE CMake API documentation](https://github.com/juce-framework/JUCE/blob/master/docs/CMake%20API.md) for detailed behaviour of each option.

If you're using [ZLS](https://github.com/zigtools/zls), your editor can show available
values and jump to definitions, making it easy to inspect each field.

Note that some fields are not yet implemented.

| `juce_add_<target>` argument | ProjectConfig field |
| ---------------------------- | ------------------- |
| `PRODUCT_NAME` | `product_name` |
| `VERSION` | `version` |
| `BUILD_VERSION` | `build_version` |
| `BUNDLE_ID` | `bundle_id` |
| `MICROPHONE_PERMISSION_ENABLED` | `microphone_permission_enabled` |
| `MICROPHONE_PERMISSION_TEXT` | `microphone_permission_text` |
| `CAMERA_PERMISSION_ENABLED` | `camera_permission_enabled` |
| `CAMERA_PERMISSION_TEXT` | `camera_permission_text` |
| `BLUETOOTH_PERMISSION_ENABLED` | `bluetooth_permission_enabled` |
| `BLUETOOTH_PERMISSION_TEXT` | `bluetooth_permission_text` |
| `LOCAL_NETWORK_PERMISSION_ENABLED` | `local_network_permission_enabled` |
| `LOCAL_NETWORK_PERMISSION_TEXT` | `local_network_permission_text` |
| `SEND_APPLE_EVENTS_PERMISSION_ENABLED` | `send_apple_events_permission_enabled` |
| `SEND_APPLE_EVENTS_PERMISSION_TEXT` | `send_apple_events_permission_text` |
| `FILE_SHARING_ENABLED` | *(not implemented)* |
| `DOCUMENT_BROWSER_ENABLED` | *(not implemented)* |
| `STATUS_BAR_HIDDEN` | *(not implemented)* |
| `REQUIRES_FULL_SCREEN` | *(not implemented)* |
| `BACKGROUND_AUDIO_ENABLED` | *(not implemented)* |
| `BACKGROUND_BLE_ENABLED` | *(not implemented)* |
| `APP_GROUPS_ENABLED` | *(not implemented)* |
| `APP_GROUP_IDS` | *(not implemented)* |
| `ICLOUD_PERMISSIONS_ENABLED` | *(not implemented)* |
| `IPHONE_SCREEN_ORIENTATIONS` | *(not implemented)* |
| `IPAD_SCREEN_ORIENTATIONS` | *(not implemented)* |
| `LAUNCH_STORYBOARD_FILE` | *(not implemented)* |
| `CUSTOM_XCASSETS_FOLDER` | *(not implemented)* |
| `TARGETED_DEVICE_FAMILY` | *(not implemented)* |
| `ICON_BIG` | *(not implemented)* |
| `ICON_SMALL` | *(not implemented)* |
| `COMPANY_COPYRIGHT` | `company_copyright` |
| `COMPANY_NAME` | `company_name` |
| `COMPANY_WEBSITE` | `company_website` |
| `COMPANY_EMAIL` | `company_email` |
| `DOCUMENT_EXTENSIONS` | `document_extensions` |
| `NEEDS_CURL` | `needs_curl` |
| `NEEDS_WEB_BROWSER` | `needs_web_browser` |
| `NEEDS_WEBVIEW2` | `needs_webview2` |
| `NEEDS_STORE_KIT` | `needs_store_kit` |
| `PUSH_NOTIFICATIONS_ENABLED` | *(not implemented)* |
| `NETWORK_MULTICAST_ENABLED` | *(not implemented)* |
| `HARDENED_RUNTIME_ENABLED` | *(not implemented)* |
| `HARDENED_RUNTIME_OPTIONS` | *(not implemented)* |
| `APP_SANDBOX_ENABLED` | *(not implemented)* |
| `APP_SANDBOX_INHERIT` | *(not implemented)* |
| `APP_SANDBOX_OPTIONS` | *(not implemented)* |
| `APP_SANDBOX_FILE_ACCESS_HOME_RO` | *(not implemented)* |
| `APP_SANDBOX_FILE_ACCESS_HOME_RW` | *(not implemented)* |
| `APP_SANDBOX_FILE_ACCESS_ABS_RO` | *(not implemented)* |
| `APP_SANDBOX_FILE_ACCESS_ABS_RW` | *(not implemented)* |
| `APP_SANDBOX_EXCEPTION_IOKIT` | *(not implemented)* |
| `PLIST_TO_MERGE` | `plist_to_merge` |
| `FORMATS` | `formats` |
| `PLUGIN_NAME` | `plugin_name` |
| `PLUGIN_MANUFACTURER_CODE` | `plugin_manufacturer_code` |
| `PLUGIN_CODE` | `plugin_code` |
| `DESCRIPTION` | `description` |
| `IS_SYNTH` | `is_synth` |
| `NEEDS_MIDI_INPUT` | `needs_midi_input` |
| `NEEDS_MIDI_OUTPUT` | `needs_midi_output` |
| `IS_MIDI_EFFECT` | `is_midi_effect` |
| `EDITOR_WANTS_KEYBOARD_FOCUS` | `editor_wants_keyboard_focus` |
| `DISABLE_AAX_BYPASS` | *(not implemented)* |
| `DISABLE_AAX_MULTI_MONO` | *(not implemented)* |
| `AAX_IDENTIFIER` | *(not implemented)* |
| `LV2URI` | *(not implemented)* |
| `VST_NUM_MIDI_INS` | `vst_num_midi_ins` |
| `VST_NUM_MIDI_OUTS` | `vst_num_midi_outs` |
| `VST2_CATEGORY` | `vst2_category` |
| `VST3_CATEGORIES` | `vst3_categories` |
| `AU_MAIN_TYPE` | `au_main_type` |
| `AU_EXPORT_PREFIX` | `au_export_prefix` |
| `AU_SANDBOX_SAFE` | `au_sandbox_safe` |
| `SUPPRESS_AU_PLIST_RESOURCE_USAGE` | `suppress_au_plist_resource_usage` |
| `AAX_CATEGORY` | *(not implemented)* |
| `PLUGINHOST_AU` | *(not implemented)* |
| `USE_LEGACY_COMPATIBILITY_PLUGIN_CODE` | `use_legacy_compatibility_plugin_code` |
| `COPY_PLUGIN_AFTER_BUILD` | *(not implemented)* |
| `VST_COPY_DIR` | *(not implemented)* |
| `VST3_COPY_DIR` | *(not implemented)* |
| `AAX_COPY_DIR` | *(not implemented)* |
| `AU_COPY_DIR` | *(not implemented)* |
| `UNITY_COPY_DIR` | *(not implemented)* |
| `IS_ARA_EFFECT` | *(not implemented)* |
| `ARA_FACTORY_ID` | *(not implemented)* |
| `ARA_DOCUMENT_ARCHIVE_ID` | *(not implemented)* |
| `ARA_ANALYSIS_TYPES` | *(not implemented)* |
| `ARA_TRANSFORMATION_FLAGS` | *(not implemented)* |
| `VST3_AUTO_MANIFEST` | `vst3_auto_manifest` |

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
