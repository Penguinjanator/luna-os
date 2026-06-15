# luna-widget.nix — Luna's KDE panel chat widget (Plasma 6 plasmoid).
#
# Installs the plasmoid under share/plasma/plasmoids/<id> so Plasma discovers it
# in the "Add Widgets" list. It's pure QML (org.kde.plasma.plasmoid + Kirigami +
# QtQuick.Controls, all present in a Plasma 6 session), talking to the always-on
# dashboard's /api/chat — so no runtime deps to bundle here.
#
# Imported by kde.nix only (GNOME gets the mirror as a Shell extension). After a
# rebuild + relogin, add it via right-click panel -> Add Widgets -> "Luna".
{ pkgs, ... }:
let
  lunaPlasmoid = pkgs.runCommandLocal "luna-plasmoid" { } ''
    dest=$out/share/plasma/plasmoids/org.luna.chat
    mkdir -p "$dest"
    cp -r ${./luna-plasmoid}/. "$dest/"
    chmod -R u+w "$dest"
  '';
in
{
  environment.systemPackages = [ lunaPlasmoid ];

  # Let the plasmoid's XHR fallback read the dashboard token file — Qt blocks
  # QML file:// reads unless this is set. The primary path is Plasma's executable
  # data source; this covers sessions where that engine isn't available.
  environment.sessionVariables.QML_XHR_ALLOW_FILE_READ = "1";
}
