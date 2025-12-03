{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zig.url = "github:mitchellh/zig-overlay";
  };

  outputs =
    {
      zig,
      nixpkgs,
      ...
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
          default = pkgs.mkShell {
            packages =
              with pkgs;
              [
                zig.packages.${stdenv.hostPlatform.system}."0.15.2"
                zls
              ]
              # JUCE Dependencies on Linux
              # https://github.com/juce-framework/JUCE/blob/master/docs/Linux%20Dependencies.md#packages
              ++ lib.optionals stdenv.isLinux [
                pkg-config
                llvmPackages.bintools

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
                xorg.libX11
                xorg.libXcomposite
                xorg.libXcursor
                xorg.libXext
                xorg.libXinerama
                xorg.libXrandr
                xorg.libXrender

                # juce_gui_extra
                webkitgtk_4_1

                # others
                libuuid
                libxkbcommon
                libthai
                libdatrie
                libepoxy
                libselinux
                libsepol
                libsysprof-capture
                xorg.libXdmcp
                xorg.libXtst
                lerc
                pcre2
                sqlite
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
