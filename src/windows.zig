const std = @import("std");
const Juceaide = @import("Juceaide.zig");

pub fn addResourcesRc(
    module: *std.Build.Module,
    juceaide: Juceaide,
    info_text_file: std.Build.LazyPath,
) void {
    const b = module.owner;
    const rcfile_cmd = b.addRunArtifact(juceaide.artifact);
    rcfile_cmd.addArg("rcfile");
    rcfile_cmd.addFileArg(info_text_file);
    const out_rcfile = rcfile_cmd.addOutputFileArg("resources.rc");
    module.addWin32ResourceFile(.{ .file = out_rcfile });
}

pub fn createManifest(b: *std.Build) std.Build.LazyPath {
    const files = b.addWriteFiles();
    const manifest = files.add("m.manifest",
        \\<?xml version="1.0" standalone="yes"?>
        \\<assembly xmlns="urn:schemas-microsoft-com:asm.v1"
        \\          manifestVersion="1.0">
        \\  <trustInfo>
        \\    <security>
        \\      <requestedPrivileges>
        \\         <requestedExecutionLevel level='asInvoker' uiAccess='false'/>
        \\      </requestedPrivileges>
        \\    </security>
        \\  </trustInfo>
        \\  <dependency>
        \\    <dependentAssembly>
        \\      <assemblyIdentity type='Win32' name='Microsoft.Windows.Common-Controls' version='6.0.0.0' processorArchitecture='*' publicKeyToken='6595b64144ccf1df' language='*' />
        \\    </dependentAssembly>
        \\  </dependency>
        \\</assembly>
    );
    return manifest;
}
