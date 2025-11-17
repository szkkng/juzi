{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zig.url = "github:mitchellh/zig-overlay";
  };

  outputs =
    {
      self,
      zig,
      nixpkgs,
    }:
    let
      allSystems = [
        "x86_64-darwin"
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems =
        f: nixpkgs.lib.genAttrs allSystems (system: f { pkgs = import nixpkgs { inherit system; }; });
    in
    {
      devShells = forAllSystems (
        { pkgs }:
        {
          default = pkgs.mkShell.override { stdenv = pkgs.llvmPackages_20.stdenv; } {
            buildInputs = [
              pkgs.apple-sdk_15
            ];

            packages = [
              zig.packages.${pkgs.system}."0.15.2"
              pkgs.zls
              pkgs.lldb_20
              pkgs.gersemi
              pkgs.llvmPackages_20.clang-tools
              pkgs.llvmPackages_20.libllvm
              pkgs.vscode-extensions.vadimcn.vscode-lldb.adapter
              pkgs.neocmakelsp
              pkgs.codex
            ];

            shellHook = ''
              # We unset some NIX environment variables that might interfere with the zig
              # compiler.
              # Issue: https://github.com/ziglang/zig/issues/18998
              unset NIX_CFLAGS_COMPILE
              unset NIX_LDFLAGS
              export PATH=$(echo "$PATH" | sed "s|${pkgs.xcbuild.xcrun}/bin:||g")
            '';
          };

        }
      );
    };
}
