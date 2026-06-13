# kde.nix — the KDE Plasma 6 desktop layer.
#
# One of the three desktop options (gnome / kde / terminal). The flake layers
# exactly one of these onto a base system to produce a "flavor". Booting the KDE
# ISO drops you into a live Plasma session; the installed system gets Plasma as
# its desktop. Terminal-only = none of these modules.
{ pkgs, ... }:
{
  # X stack (also provides XWayland + xkb config for the default Wayland session).
  services.xserver.enable = true;

  # SDDM greeter + the Plasma 6 desktop itself.
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.desktopManager.plasma6.enable = true;

  # The minimal-ISO base installs no fonts, so fontconfig has nothing to hand
  # Chromium/Electron — text renders as blank glyphs (you see buttons + inputs
  # but no words). Pull in the default font set (this also wires up fontconfig).
  fonts.enableDefaultPackages = true;

  # Desktop apps. Telegram Desktop: log into your account and use its "Saved
  # Messages" (message-to-self) as a host<->guest clipboard bridge — far more
  # reliable than VirtualBox's clipboard under Wayland. fontconfig: the fc-list /
  # fc-match CLI, for checking what fonts are actually available.
  environment.systemPackages = with pkgs; [
    telegram-desktop
    fontconfig
    fsearch # fast GUI file search
  ];
}
