const std = @import("std");

pub fn addAdhocCodeSign(
    b: *std.Build,
    artifact_path: []const u8,
) *std.Build.Step.Run {
    const adhoc_sign_cmd = b.addSystemCommand(&.{
        "codesign",
        "--sign",
        "-",
        "--force",
        artifact_path,
    });
    adhoc_sign_cmd.has_side_effects = true;
    _ = adhoc_sign_cmd.captureStdErr();
    return adhoc_sign_cmd;
}
