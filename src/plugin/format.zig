// TODO: support more plugin formats
pub const PluginFormat = enum {
    vst3,
    standalone,
    // vst,
    au,
    // auv3,
    // aax,
    // lv2,
    // unity,

    pub fn internalIdentifier(self: PluginFormat) []const u8 {
        return switch (self) {
            .vst3 => "VST3",
            .standalone => "Standalone Plugin",
            // .vst => "VST",
            .au => "AU",
            // .auv3 => "AUv3 AppExtension",
            // .aax => "AAX",
            // .lv2 => "LV2",
            // .unity => "Unity Plugin",
        };
    }
};
