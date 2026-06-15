# luna-search.nix — "ask Luna from the search bar" for both desktops.
#
# Ships luna-search (the D-Bus bridge in luna-search.py) plus the descriptors
# that point KRunner and the GNOME overview at it:
#   • KDE   — a krunner/dbusplugins/*.desktop runner descriptor (org.kde.krunner1)
#   • GNOME — a gnome-shell/search-providers/*.ini (org.gnome.Shell.SearchProvider2)
#   • both  — D-Bus .service files so the shell activates luna-search on demand
#
# Imported by kde.nix + gnome.nix. The descriptors are inert on the "wrong"
# desktop (KDE ignores the GNOME ini, GNOME ignores the krunner plugin), so one
# module serves both and only the matching shell ever activates its service. The
# answer popup is luna-ask-dialog from luna-launchers.nix, shipped alongside.
{ pkgs, lib, ... }:
let
  pyEnv = pkgs.python3.withPackages (ps: with ps; [ dbus-python pygobject3 ]);

  # Rewrite the dev shebang to the dbus/gobject-enabled interpreter, and gate the
  # build on it compiling against that real interpreter.
  lunaSearch = pkgs.runCommandLocal "luna-search" { } ''
    install -Dm755 ${./luna-search.py} $out/bin/luna-search
    substituteInPlace $out/bin/luna-search \
      --replace '#!/usr/bin/env python3' '#!${pyEnv}/bin/python3'
    ${pyEnv}/bin/python3 -m py_compile $out/bin/luna-search
  '';

  # KDE reads krunner/dbusplugins/*.desktop; X-Plasma-API=DBus + service/path tell
  # KRunner which bus name to query (org.kde.krunner1 at /runner).
  krunnerPlugin = pkgs.writeTextDir "share/krunner/dbusplugins/luna.desktop" ''
    [Desktop Entry]
    Type=Service
    Name=Luna
    Comment=Ask Luna, your AI companion
    Icon=im-user
    X-KDE-PluginInfo-Author=luna-os
    X-KDE-PluginInfo-Name=luna
    X-KDE-PluginInfo-EnabledByDefault=true
    X-Plasma-API=DBus
    X-Plasma-Request-Actions-Once=true
    X-Plasma-DBusRunner-Service=org.luna.Runner
    X-Plasma-DBusRunner-Path=/runner
  '';

  # GNOME Shell scans gnome-shell/search-providers/*.ini; DesktopId ties the
  # results to the "Ask Luna" app entry (luna-ask.desktop, from luna-launchers).
  gnomeProvider = pkgs.writeTextDir "share/gnome-shell/search-providers/luna-search-provider.ini" ''
    [Shell Search Provider]
    DesktopId=luna-ask.desktop
    BusName=org.luna.SearchProvider
    ObjectPath=/org/luna/SearchProvider
    Version=2
  '';

  # D-Bus activation: the shell starts luna-search on demand by bus name.
  runnerService = pkgs.writeTextDir "share/dbus-1/services/org.luna.Runner.service" ''
    [D-BUS Service]
    Name=org.luna.Runner
    Exec=${lunaSearch}/bin/luna-search krunner
  '';

  searchService = pkgs.writeTextDir "share/dbus-1/services/org.luna.SearchProvider.service" ''
    [D-BUS Service]
    Name=org.luna.SearchProvider
    Exec=${lunaSearch}/bin/luna-search gnome-search
  '';
in
{
  environment.systemPackages = [ lunaSearch krunnerPlugin gnomeProvider ];
  # Registers the activation .service files on the session bus.
  services.dbus.packages = [ runnerService searchService ];
}
