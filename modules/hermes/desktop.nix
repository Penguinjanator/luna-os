# modules/hermes/desktop.nix — Luna's face on the desktop variants.
#
# Installs the Hermes Electron app (built from our pinned `hermes` fork) so it's
# in the app menu / dock. Desktop-only — the gnome/kde layers import this;
# terminal/headless never do.
#
# We do NOT modify the app here. Our changes (import/export, ambient presence)
# live in the fork at apps/desktop/, done merge-friendly, and arrive in luna-os
# via `nix flake update hermes`. This module only *delivers* the app.
{ hermes, pkgs, lib, ... }:
let
  hermesDesktop = hermes.packages.${pkgs.stdenv.hostPlatform.system}.desktop;

  # Force software rendering. Chromium's GPU process fails EGL/GL init in VMs,
  # under WSL, and anywhere the GPU stack isn't wired up — and instead of
  # falling back gracefully it takes the whole UI down (blank/garbled). The
  # --disable-gpu flag routes to the software rasterizer (needs no libGL) and
  # paints correctly everywhere; a chat UI doesn't need accel. Drop the flag if
  # you're targeting real GPU hardware and want it back.
  hermesDesktopGui = pkgs.symlinkJoin {
    name = "hermes-desktop-gui";
    paths = [ hermesDesktop ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/hermes-desktop --add-flags "--disable-gpu"
    '';
  };

  launcher = pkgs.makeDesktopItem {
    name = "hermes-desktop";
    desktopName = "Luna";
    genericName = "Hermes Agent";
    comment = "Talk to your Hermes agent";
    exec = "${hermesDesktopGui}/bin/hermes-desktop";
    icon = "${hermesDesktop}/share/hermes-desktop/dist/apple-touch-icon.png";
    categories = [ "Utility" "Network" ];
    terminal = false;
  };
in
{
  # In the app menu / dock, with the binary on PATH. No autostart — she's one
  # click away in the launcher, not forced open on login.
  environment.systemPackages = [ hermesDesktopGui launcher ];
}
