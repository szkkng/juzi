{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zig = {
      url = "github:silversquirl/zig-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      zig,
      nixpkgs,
      ...
    }:
    let
      forAllSystems = f: builtins.mapAttrs f nixpkgs.legacyPackages;
    in
    {
      devShells = forAllSystems (
        system: pkgs: {
          default = pkgs.mkShell {
            packages =
              with pkgs;
              [
                zig.packages.${system}.default
                zig.packages.${system}.default.zls
              ]
              # JUCE Dependencies on Linux
              # https://github.com/juce-framework/JUCE/blob/master/docs/Linux%20Dependencies.md#packages
              ++ lib.optionals stdenv.isLinux [
                pkg-config

                # juce_audio_devices
                alsa-lib
                libjack2

                # juce_audio_processors
                ladspa-sdk

                # juce_core
                curl

                # juce_graphics
                fontconfig
                freetype

                # juce_gui_basics
                libx11
                libxcomposite
                libxcursor
                libxext
                libxinerama
                libxrandr
                libxrender
                libxi

                # juce_gui_extra
                webkitgtk_4_1
              ];

            shellHook = pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
              # We adjust Nix-provided compiler flags that may interfere with zig
              export NIX_CFLAGS_COMPILE=$(echo "$NIX_CFLAGS_COMPILE" | sed -E "s|-fmacro-prefix-map=[^ ]+||g")
              export PATH=$(echo "$PATH" | sed "s|${pkgs.xcbuild.xcrun}/bin:||g")
            '';
          };
        }
      );
    };
}
