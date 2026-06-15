# luna-desktop.nix — Luna's native client, built from the pinned luna-desktop
# repo's `cli/` crate. It's BOTH the `luna` CLI (ask / chat / status / sessions /
# repl) AND the graphical chat (`luna gui`): a Slint frosted-glass window + a
# StatusNotifierItem tray + freedesktop notifications — the universal desktop
# surface that replaces the old per-desktop widgets.
#
# Imported by EVERY variant (like luna.nix) so `luna` is always available; the
# desktop layers (kde.nix / gnome.nix) add the launcher + autostart that point at
# it. Built with buildRustPackage from the repo's committed Cargo.lock.
{ pkgs, luna-desktop, ... }:
let
  lib = pkgs.lib;

  # Libraries the GUI needs at RUNTIME. `luna gui` uses Slint's software renderer
  # (no GL needed for drawing — survives flaky-GPU VMs), but winit still dlopens
  # the windowing/input libs to put a window on X11/Wayland, and fontconfig is
  # linked outright (the binary's only non-libc NEEDED entry). NixOS has no
  # /usr/lib, so these must be baked onto the binary's LD_LIBRARY_PATH.
  guiRuntimeLibs = with pkgs; [
    fontconfig
    freetype
    libxkbcommon
    wayland
    libGL
    libx11
    libxcursor
    libxi
    libxrandr
  ];

  luna-cli = pkgs.rustPlatform.buildRustPackage {
    pname = "luna-cli";
    version = "0.1.0";
    src = "${luna-desktop}/cli";
    cargoLock.lockFile = "${luna-desktop}/cli/Cargo.lock";

    # pkg-config + fontconfig satisfy yeslogic-fontconfig-sys's build probe (the
    # GUI's font stack); makeWrapper bakes the runtime library path in.
    nativeBuildInputs = [ pkgs.pkg-config pkgs.makeWrapper ];
    buildInputs = [ pkgs.fontconfig pkgs.freetype ];

    postInstall = ''
      wrapProgram $out/bin/luna \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath guiRuntimeLibs}
    '';

    meta.mainProgram = "luna";
  };
in
{
  environment.systemPackages = [ luna-cli ];
}
