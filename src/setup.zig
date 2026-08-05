const std = @import("std");
const JuceModule = @import("JuceModule.zig");

pub const ModuleMap = std.StringHashMapUnmanaged(JuceModule);

pub const CxxStandard = enum {
    cxx17,
    cxx20,
    cxx23,

    pub fn flag(self: CxxStandard) []const u8 {
        return switch (self) {
            .cxx17 => "--std=c++17",
            .cxx20 => "--std=c++20",
            .cxx23 => "--std=c++23",
        };
    }
};

pub fn resolveModules(
    b: *std.Build,
    requested_modules: []const JuceModule,
) ModuleMap {
    var modules: ModuleMap = .empty;

    for (requested_modules) |juce_module| {
        collectModule(b, &modules, juce_module);
    }

    return modules;
}

pub fn addModules(
    root_module: *std.Build.Module,
    modules: ModuleMap,
    ctx: JuceModule.BuildContext,
) void {
    var iter = modules.valueIterator();
    while (iter.next()) |module| {
        module.*.configure(root_module, ctx);
    }
}

fn collectModule(
    b: *std.Build,
    modules: *ModuleMap,
    juce_module: JuceModule,
) void {
    if (modules.contains(juce_module.name)) return;

    modules.put(b.allocator, juce_module.name, juce_module) catch @panic("OOM");
    for (juce_module.deps) |dependency| {
        collectModule(b, modules, dependency);
    }
}

pub fn resolveRequiredFlags(
    b: *std.Build,
    modules: ModuleMap,
    cxx_standard: CxxStandard,
    extra_flags: []const []const u8,
) JuceModule.RequiredFlags {
    var common: std.ArrayList([]const u8) = .empty;
    common.appendSlice(b.allocator, extra_flags) catch @panic("OOM");
    common.appendSlice(b.allocator, getModuleAvailableDefs(b, modules)) catch @panic("OOM");
    common.append(b.allocator, "-fvisibility=hidden") catch @panic("OOM");

    const c_flags = common.toOwnedSlice(b.allocator) catch @panic("OOM");

    var cxx: std.ArrayList([]const u8) = .empty;
    cxx.appendSlice(b.allocator, c_flags) catch @panic("OOM");
    cxx.append(b.allocator, "-fvisibility-inlines-hidden") catch @panic("OOM");
    cxx.append(b.allocator, cxx_standard.flag()) catch @panic("OOM");

    // Zig enforces -Werror=date-time in release builds for reproducible builds,
    // but juce_core_CompilationTime.cpp uses __DATE__/__TIME__.
    // Disable this error as a workaround to allow JUCE to build.
    // https://github.com/ziglang/zig/pull/20821/commits/ff7bdbbd7d997b22f50704c5268839bea9321088
    cxx.append(b.allocator, "-Wno-error=date-time") catch @panic("OOM");

    // JUCE's AU plugin client can use enum values outside the usual range,
    // which trips UBSan's enum checks when loading debug AU plugins.
    // Zig enables these UBSan checks by default, so disable them here.
    // https://github.com/juce-framework/JUCE/blob/1b460fe0895635a2ab8ac5c00cb5575e33e5dc1e/modules/juce_audio_plugin_client/juce_audio_plugin_client_AU_1.mm#L944
    cxx.append(b.allocator, "-fno-sanitize=enum") catch @panic("OOM");

    return .{
        .c = c_flags,
        .cxx = cxx.toOwnedSlice(b.allocator) catch @panic("OOM"),
    };
}

pub fn addStandardDefs(module: *std.Build.Module, optimize: std.builtin.OptimizeMode) void {
    module.addCMacro("JUCE_GLOBAL_MODULE_SETTINGS_INCLUDED", "1");

    if (optimize == .Debug) {
        module.addCMacro("DEBUG", "1");
        module.addCMacro("_DEBUG", "1");
    } else {
        module.addCMacro("NDEBUG", "1");
        module.addCMacro("_NDEBUG", "1");
    }
}

fn getModuleAvailableDefs(
    b: *std.Build,
    modules: ModuleMap,
) []const []const u8 {
    var defs: std.ArrayList([]const u8) = .empty;
    var names = modules.keyIterator();
    while (names.next()) |name| {
        defs.append(b.allocator, b.fmt("-DJUCE_MODULE_AVAILABLE_{s}=1", .{name.*})) catch @panic("OOM");
    }
    return defs.toOwnedSlice(b.allocator) catch @panic("OOM");
}

pub fn addFlagsToLinkObjects(module: *std.Build.Module, flags: []const []const u8) void {
    const b = module.owner;
    for (module.link_objects.items) |link_object| {
        switch (link_object) {
            .c_source_file => updateFlags(std.Build.Module.CSourceFile, b, link_object.c_source_file, flags),
            .c_source_files => updateFlags(std.Build.Module.CSourceFiles, b, link_object.c_source_files, flags),
            else => {},
        }
    }
}

fn updateFlags(T: type, b: *std.Build, source: *T, flags: []const []const u8) void {
    if (T != std.Build.Module.CSourceFile and T != std.Build.Module.CSourceFiles) {
        @compileError("Needs to be CSourceFile or CSourceFiles");
    }
    source.flags = std.mem.concat(b.allocator, []const u8, &.{
        source.flags,
        flags,
    }) catch @panic("OOM");
}
