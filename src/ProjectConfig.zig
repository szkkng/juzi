const std = @import("std");
const ProjectConfig = @This();
const PluginFormat = @import("plugin/format.zig").PluginFormat;
pub const Vst2Category = @import("plugin/category.zig").Vst2Category;
pub const Vst3Category = @import("plugin/category.zig").Vst3Category;
pub const AudioUnitMainType = @import("plugin/category.zig").AudioUnitMainType;

// TODO: add more fields
// https://github.com/juce-framework/JUCE/blob/master/docs/CMake%20API.md#juce_add_target
product_name: []const u8,
version: []const u8,
build_version: []const u8,
bundle_id: []const u8,

microphone_permission_enabled: ?bool,
microphone_permission_text: []const u8,
camera_permission_enabled: ?bool,
camera_permission_text: []const u8,
bluetooth_permission_enabled: ?bool,
bluetooth_permission_text: []const u8,
local_network_permission_enabled: ?bool,
local_network_permission_text: []const u8,
send_apple_events_permission_enabled: ?bool,
send_apple_events_permission_text: []const u8,

// file_sharing_enabled: ?bool,
// document_browser_enabled: ?bool,
// status_bar_hidden: ?bool,
// requires_full_screen: ?bool,
// background_audio_enabled: ?bool,
// background_ble_enabled : ?bool,
// app_groups_enabled: ?bool,
// app_group_ids: ?[]const u8,
// icloud_permissions_enabled: ?bool,
// iphone_screen_orientations
// ipad_screen_orientations
// launch_storyboard_file
// custom_xcassets_folder
// targeted_device_family

// icon_big: ?[]const u8,
// icon_small: ?[]const u8,

company_copyright: []const u8,
company_name: []const u8,
company_website: []const u8,
company_email: []const u8,

document_extensions: []const []const u8,

needs_curl: bool,
needs_web_browser: bool,
needs_webview2: bool,
needs_store_kit: bool,

// push_notifications_enabled: bool,
// network_multicast_enabled: bool,
// hardened_runtime_enabled: bool,
// hardened_runtime_options: []const []const u8,
// app_sandbox_enabled: bool,
// app_sandbox_inherit: bool,
// app_sandbox_options: []const []const u8,
// app_sandbox_file_access_home_ro: []const []const u8,
// app_sandbox_file_access_abs_ro: []const []const u8,
// app_sandbox_file_access_abs_rw: []const []const u8,
// app_sandbox_exception_iokit: []const []const u8,
plist_to_merge: []const u8,

formats: []const PluginFormat,
plugin_name: []const u8,
plugin_manufacturer_code: []const u8,

plugin_code: []const u8,
description: []const u8,
is_synth: bool,
needs_midi_input: bool,
needs_midi_output: bool,
is_midi_effect: bool,
editor_wants_keyboard_focus: bool,

// disable_aax_bypass
// disable_aax_multi_mono
// aax_identifier
// lv2uri
vst_num_midi_ins: u8,
vst_num_midi_outs: u8,
vst2_category: Vst2Category,
vst3_categories: []const Vst3Category,

au_main_type: AudioUnitMainType,
au_export_prefix: []const u8,
au_sandbox_safe: bool,
suppress_au_plist_resource_usage: bool,
// aax_category
// pluginhost_au

use_legacy_compatibility_plugin_code: bool,

// copy_plugin_after_build: bool = true,
// vst_copy_dir
// vst3_copy_dir
// aax_copy_dir
// au_copy_dir
// unity_copy_dir

// is_ara_effect
// ara_factory_id
// ara_document_archive_id
// ara_analysis_types
// ara_transformation_flags

vst3_auto_manifest: bool,

const CreateOptions = struct {
    product_name: []const u8,
    version: []const u8,
    build_version: ?[]const u8 = null,
    bundle_id: ?[]const u8 = null,
    microphone_permission_enabled: ?bool = null,
    microphone_permission_text: []const u8 = "",
    camera_permission_enabled: ?bool = null,
    camera_permission_text: []const u8 = "",
    bluetooth_permission_enabled: ?bool = null,
    bluetooth_permission_text: []const u8 = "",
    local_network_permission_enabled: ?bool = null,
    local_network_permission_text: []const u8 = "",
    send_apple_events_permission_enabled: ?bool = null,
    send_apple_events_permission_text: []const u8 = "",
    // icon_big: ?[]const u8 = null,
    // icon_small: ?[]const u8 = null,
    company_copyright: []const u8 = "",
    company_name: []const u8 = "yourcompany",
    company_website: []const u8 = "",
    company_email: []const u8 = "",
    document_extensions: []const []const u8 = &.{},
    needs_curl: bool = true,
    needs_web_browser: bool = true,
    needs_webview2: bool = false,
    needs_store_kit: bool = false,
    plist_to_merge: []const u8 = "",
    formats: []const PluginFormat = &.{},
    plugin_name: ?[]const u8 = null,
    plugin_manufacturer_code: []const u8 = "Manu",
    plugin_code: ?[]const u8 = null,
    description: ?[]const u8 = null,
    is_synth: bool = false,
    needs_midi_output: bool = false,
    needs_midi_input: bool = false,
    is_midi_effect: bool = false,
    editor_wants_keyboard_focus: bool = false,
    vst3_auto_manifest: bool = true,
    vst2_category: ?Vst2Category = null,
    vst3_categories: ?[]const Vst3Category = null,
    au_main_type: ?AudioUnitMainType = null,
    au_export_prefix: ?[]const u8 = null,
    au_sandbox_safe: bool = false,
    suppress_au_plist_resource_usage: bool = false,
    vst_num_midi_ins: u8 = 16,
    vst_num_midi_outs: u8 = 16,
    use_legacy_compatibility_plugin_code: bool = false,
};

pub fn create(b: *std.Build, options: CreateOptions) ProjectConfig {
    const bundle_id = options.bundle_id orelse b.fmt("com.{s}.{s}", .{ options.company_name, options.product_name });
    if (std.mem.containsAtLeast(u8, bundle_id, 1, " ")) {
        @panic(b.fmt("Invalid bundle identifier '{s}': cannot contain spaces", .{bundle_id}));
    }

    const au_main_type: AudioUnitMainType =
        if (options.is_midi_effect)
            .kAudioUnitType_MIDIProcessor
        else if (options.is_synth)
            .kAudioUnitType_MusicDevice
        else if (options.needs_midi_input)
            .kAudioUnitType_MusicEffect
        else
            .kAudioUnitType_Effect;

    const au_prefix = options.au_export_prefix orelse b.fmt("{s}AU", .{makeCIdentifier(b.allocator, options.product_name)});

    return .{
        .product_name = options.product_name,
        .version = options.version,
        .build_version = options.build_version orelse options.version,
        .bundle_id = bundle_id,

        .microphone_permission_enabled = options.microphone_permission_enabled,
        .microphone_permission_text = options.microphone_permission_text,
        .camera_permission_enabled = options.camera_permission_enabled,
        .camera_permission_text = options.camera_permission_text,
        .bluetooth_permission_enabled = options.bluetooth_permission_enabled,
        .bluetooth_permission_text = options.bluetooth_permission_text,
        .local_network_permission_enabled = options.local_network_permission_enabled,
        .local_network_permission_text = options.local_network_permission_text,
        .send_apple_events_permission_enabled = options.send_apple_events_permission_enabled,
        .send_apple_events_permission_text = options.send_apple_events_permission_text,

        // .icon_big = options.icon_big,
        // .icon_small = options.icon_small,

        .company_copyright = options.company_copyright,
        .company_name = options.company_name,
        .company_website = options.company_website,
        .company_email = options.company_email,

        .document_extensions = options.document_extensions,

        .needs_curl = options.needs_curl,
        .needs_web_browser = options.needs_web_browser,
        .needs_webview2 = options.needs_webview2,
        .needs_store_kit = options.needs_store_kit,

        .plugin_name = options.plugin_name orelse options.product_name,
        .plugin_manufacturer_code = if (options.use_legacy_compatibility_plugin_code) "proj" else options.plugin_manufacturer_code,
        .plugin_code = options.plugin_code orelse makeValid4cc(b),
        .formats = options.formats,
        .description = options.description orelse options.product_name,
        .is_synth = options.is_synth,
        .is_midi_effect = options.is_midi_effect,
        .needs_midi_output = options.needs_midi_output,
        .needs_midi_input = options.needs_midi_input,
        .editor_wants_keyboard_focus = options.editor_wants_keyboard_focus,
        .vst2_category = options.vst2_category orelse Vst2Category.default(options.is_synth),
        .vst3_categories = Vst3Category.withDefaults(b.allocator, options.vst3_categories orelse &.{}, options.is_synth) catch @panic("OOM"),
        .au_main_type = au_main_type,
        .au_export_prefix = au_prefix,
        .au_sandbox_safe = options.au_sandbox_safe,
        .suppress_au_plist_resource_usage = options.suppress_au_plist_resource_usage,
        .vst_num_midi_ins = options.vst_num_midi_ins,
        .vst_num_midi_outs = options.vst_num_midi_outs,
        .plist_to_merge = options.plist_to_merge,

        .use_legacy_compatibility_plugin_code = options.use_legacy_compatibility_plugin_code,
        .vst3_auto_manifest = options.vst3_auto_manifest,
    };
}

fn makeCIdentifier(allocator: std.mem.Allocator, input: []const u8) []const u8 {
    var result = std.ArrayList(u8).empty;

    if (input.len == 0) {
        return result.toOwnedSlice(allocator) catch @panic("OOM");
    }

    if (std.ascii.isDigit(input[0])) {
        result.insert(allocator, 0, '_') catch @panic("OOM");
    }

    for (input) |c| {
        if (!std.ascii.isAlphanumeric(c)) {
            result.append(allocator, '_') catch @panic("OOM");
        } else {
            result.append(allocator, c) catch @panic("OOM");
        }
    }

    return result.toOwnedSlice(allocator) catch @panic("OOM");
}

fn makeValid4cc(b: *std.Build) []const u8 {
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    const random = prng.random();
    var result: [4]u8 = undefined;
    for (0..4) |i| {
        result[i] = switch (i) {
            0 => 'A' + @as(u8, random.uintLessThan(u8, 26)),
            else => 'a' + @as(u8, random.uintLessThan(u8, 26)),
        };
    }
    return b.dupe(result[0..]);
}
