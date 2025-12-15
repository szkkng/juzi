const std = @import("std");
const Juceaide = @This();
const Setup = @import("Setup.zig");
const juce_build_tools = @import("modules/juce_build_tools.zig").juce_module;

artifact: *std.Build.Step.Compile,

pub fn create(
    b: *std.Build,
    juzi_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
) Juceaide {
    const juce_src = juzi_dep.builder.dependency("upstream", .{});
    const optimize = .Debug;

    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });
    mod.addIncludePath(juce_src.path("modules"));
    mod.addIncludePath(juce_src.path("extras/Build"));
    mod.addCSourceFiles(.{
        .root = juce_src.path("extras/Build/juceaide"),
        .files = &.{"Main.cpp"},
    });
    var available_modules: std.StringArrayHashMapUnmanaged(*std.Build.Module) = .empty;
    mod.addImport(juce_build_tools.name, juce_build_tools.createModule(.{
        .builder = b,
        .visited = &available_modules,
        .upstream = juce_src,
        .target = target,
        .optimize = optimize,
    }));

    var flags = std.ArrayList([]const u8).empty;

    // Build juceaide in Debug to keep compile time down,
    // but use a non-Debug optimize mode here to still add -DNDEBUG=1 -D_NDEBUG=1.
    flags.appendSlice(b.allocator, Setup.getJuceCommonFlags(b, target, .ReleaseFast)) catch @panic("OOM");

    flags.appendSlice(b.allocator, Setup.getJuceModuleAvailableDefs(b, &available_modules)) catch @panic("OOM");
    flags.append(b.allocator, "-DJUCE_DISABLE_JUCE_VERSION_PRINTING=1") catch @panic("OOM");
    flags.append(b.allocator, "-DJUCE_STANDALONE_APPLICATION=1") catch @panic("OOM");
    Setup.addFlagsToLinkObjects(mod, flags.items);

    for (available_modules.values()) |m| {
        Setup.addFlagsToLinkObjects(m, flags.items);
    }

    const juceaide = b.addExecutable(.{
        .name = "juceaide",
        .root_module = mod,
    });

    return .{ .artifact = juceaide };
}
