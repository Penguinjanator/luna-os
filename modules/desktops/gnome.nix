# gnome.nix — the GNOME desktop layer.
#
# One of the three desktop options (gnome / kde / terminal). The flake layers
# exactly one of these onto a base system to produce a "flavor". Booting the
# GNOME ISO drops you into a live GNOME session; the installed system gets GNOME
# as its desktop. Terminal-only = none of these modules.
{ pkgs, ... }:
{
  # X stack (also provides XWayland + xkb config for the default Wayland session).
  services.xserver.enable = true;

  # GDM greeter + the GNOME desktop itself.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

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
