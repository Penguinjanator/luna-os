# gnome.nix — the GNOME desktop layer.
#
# One of the three desktop options (gnome / kde / terminal). The flake layers
# exactly one of these onto a base system to produce a "flavor". Booting the
# GNOME ISO drops you into a live GNOME session; the installed system gets GNOME
# as its desktop. Terminal-only = none of these modules.
{ ... }:
{
  # X stack (also provides XWayland + xkb config for the default Wayland session).
  services.xserver.enable = true;

  # GDM greeter + the GNOME desktop itself.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
}
