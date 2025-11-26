const std = @import("std");

pub const Vst2Category = enum {
    kPlugCategUnknown,
    kPlugCategEffect,
    kPlugCategSynth,
    kPlugCategAnalysis,
    kPlugCategMastering,
    kPlugCategSpacializer,
    kPlugCategRoomFx,
    kPlugSurroundFx,
    kPlugCategRestoration,
    kPlugCategOfflineProcess,
    kPlugCategShell,
    kPlugCategGenerator,

    pub fn default(is_synth: bool) Vst2Category {
        return if (is_synth) .kPlugCategSynth else .kPlugCategEffect;
    }
};

pub const Vst3Category = enum {
    Fx,
    Instrument,
    Analyzer,
    Delay,
    Distortion,
    Drum,
    Dynamics,
    EQ,
    External,
    Filter,
    Generator,
    Mastering,
    Modulation,
    Mono,
    Network,
    NoOfflineProcess,
    OnlyOfflineProcess,
    OnlyRT,
    Pitch_Shift,
    Restoration,
    Reverb,
    Sampler,
    Spatial,
    Stereo,
    Surround,
    Synth,
    Tools,
    Up_Downmix,

    pub fn internalIdentifier(self: Vst3Category) []const u8 {
        return switch (self) {
            .Pitch_Shift => "Pitch Shift",
            .Up_Downmix => "Up-Downmix",
            else => @tagName(self),
        };
    }

    // Returns a new list of categories with defaults applied.
    // Ensures `.Fx` or `.Instrument` appears first if omitted, depending on `is_synth`.
    pub fn withDefaults(
        allocator: std.mem.Allocator,
        existing_categories: []const Vst3Category,
        is_synth: bool,
    ) ![]const Vst3Category {
        if (existing_categories.len == 0) {
            return if (is_synth) &.{ .Instrument, .Synth } else &.{.Fx};
        }

        var categArray = std.ArrayList(Vst3Category).empty;

        for (existing_categories) |category| {
            try categArray.append(allocator, category);
        }

        const contains_instrument = std.mem.containsAtLeastScalar(
            Vst3Category,
            existing_categories,
            1,
            .Instrument,
        );
        const contains_fx = std.mem.containsAtLeastScalar(
            Vst3Category,
            existing_categories,
            1,
            .Fx,
        );

        if (!contains_instrument and !contains_fx) {
            try categArray.insert(allocator, 0, if (is_synth) .Instrument else .Fx);
        } else {
            if (contains_instrument) {
                const inst_index = std.mem.indexOf(Vst3Category, existing_categories, &.{.Instrument}).?;
                const inst = categArray.orderedRemove(inst_index);
                try categArray.insert(allocator, 0, inst);
            }

            if (contains_fx) {
                const fx_index = std.mem.indexOf(Vst3Category, existing_categories, &.{.Fx}).?;
                const fx = categArray.orderedRemove(fx_index);
                try categArray.insert(allocator, 0, fx);
            }
        }

        return try categArray.toOwnedSlice(allocator);
    }

    // Converts the category list into a `|`-separated VST3 category string.
    // e.g. `.{ .Fx, .Reverb }` → "Fx|Reverb"
    pub fn join(allocator: std.mem.Allocator, categories: []const Vst3Category) ![]const u8 {
        var categoryStrings = std.ArrayList([]const u8).empty;
        defer categoryStrings.deinit(allocator);
        for (categories) |category| {
            try categoryStrings.append(allocator, category.internalIdentifier());
        }
        return try std.mem.join(allocator, "|", categoryStrings.items);
    }
};

pub const AudioUnitMainType = enum {
    kAudioUnitType_Effect,
    kAudioUnitType_FormatConverter,
    kAudioUnitType_Generator,
    kAudioUnitType_MIDIProcessor,
    kAudioUnitType_Mixer,
    kAudioUnitType_MusicDevice,
    kAudioUnitType_MusicEffect,
    kAudioUnitType_OfflineEffect,
    kAudioUnitType_Output,
    kAudioUnitType_Panner,

    pub fn categoryCode(self: AudioUnitMainType) []const u8 {
        return switch (self) {
            .kAudioUnitType_Effect => "\'aufx\'",
            .kAudioUnitType_FormatConverter => "\'aufc\'",
            .kAudioUnitType_Generator => "\'augn\'",
            .kAudioUnitType_MIDIProcessor => "\'aumi\'",
            .kAudioUnitType_Mixer => "\'aumx\'",
            .kAudioUnitType_MusicDevice => "\'aumu\'",
            .kAudioUnitType_MusicEffect => "\'aumf\'",
            .kAudioUnitType_OfflineEffect => "\'auol\'",
            .kAudioUnitType_Output => "\'auou\'",
            .kAudioUnitType_Panner => "\'aupn\'",
        };
    }
};
