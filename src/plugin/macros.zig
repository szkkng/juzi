const std = @import("std");
const ProjectConfig = @import("../ProjectConfig.zig");
const Vst2Category = @import("category.zig").Vst2Category;
const Vst3Category = @import("category.zig").Vst3Category;

pub fn getPluginMacros(b: *std.Build, config: ProjectConfig) ![]const []const u8 {
    var flags = std.ArrayList([]const u8).empty;

    try flags.append(b.allocator, b.fmt("-DJUCE_STANDALONE_APPLICATION={s}", .{"JucePlugin_Build_Standalone"}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_IsSynth={d}", .{@intFromBool(config.is_synth)}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_ManufacturerCode=0x{x}", .{config.plugin_manufacturer_code}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_Manufacturer=\"{s}\"", .{config.company_name}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_ManufacturerWebsite=\"{s}\"", .{config.company_website}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_ManufacturerEmail=\"{s}\"", .{config.company_email}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_PluginCode=0x{x}", .{config.plugin_code}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_ProducesMidiOutput={d}", .{@intFromBool(config.needs_midi_output)}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_IsMidiEffect={d}", .{@intFromBool(config.is_midi_effect)}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_WantsMidiInput={d}", .{@intFromBool(config.needs_midi_input)}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_EditorRequiresKeyboardFocus={d}", .{@intFromBool(config.editor_wants_keyboard_focus)}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_Name=\"{s}\"", .{config.plugin_name}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_Desc=\"{s}\"", .{config.description}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_Version={s}", .{config.version}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_VersionString=\"{s}\"", .{config.version}));
    const version_code = try semanticVersionToVersionCode(b, config.version);
    try flags.append(b.allocator, b.fmt("-DJucePlugin_VersionCode={s}", .{version_code}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_VSTUniqueID={s}", .{"JucePlugin_PluginCode"}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_VSTCategory={s}", .{@tagName(config.vst2_category)}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_Vst3Category=\"{s}\"", .{try Vst3Category.join(b.allocator, config.vst3_categories)}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_VSTNumMidiInputs={d}", .{config.vst_num_midi_ins}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_VSTNumMidiOutputs={d}", .{config.vst_num_midi_outs}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_AUMainType={s}", .{config.au_main_type.categoryCode()}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_AUSubType={s}", .{"JucePlugin_PluginCode"}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_AUExportPrefix={s}", .{config.au_export_prefix}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_AUExportPrefixQuoted=\"{s}\"", .{config.au_export_prefix}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_AUManufacturerCode={s}", .{"JucePlugin_ManufacturerCode"}));
    try flags.append(b.allocator, b.fmt("-DJucePlugin_CFBundleIdentifier={s}", .{config.bundle_id}));

    // JucePlugin_AAXIdentifier
    // JucePlugin_AAXManufacturerCode
    // JucePlugin_AAXProductId
    // JucePlugin_AAXCategory
    // JucePlugin_AAXDisableBypass
    // JucePlugin_AAXDisableMultiMono

    // JucePlugin_Enable_ARA
    // JucePlugin_ARAFactoryID
    // JucePlugin_ARADocumentArchiveID
    // JucePlugin_ARACompatibleArchiveIDs
    // JucePlugin_ARAContentTypes
    // JucePlugin_ARATransformationFlags

    return flags.toOwnedSlice(b.allocator) catch @panic("OOM");
}

fn semanticVersionToVersionCode(b: *std.Build, ver: []const u8) ![]const u8 {
    const version = try std.SemanticVersion.parse(ver);
    const v = (version.major << 16) | (version.minor << 8) | version.patch;
    return b.fmt("0x{X}", .{v});
}
