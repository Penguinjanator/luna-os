# luna-launchers.nix — how the desktop reaches Luna's GUI.
#
# Imported by both desktop layers (kde.nix / gnome.nix), never the terminal
# variant. Everything points at the ONE universal chat app — `luna gui` (from
# luna-desktop.nix): a Slint frosted-glass window + a StatusNotifierItem tray +
# freedesktop notifications, which works on every desktop. Two pieces:
#
#   • an app-menu entry "Chat with Luna" → opens the window.
#   • an XDG autostart entry → `luna gui --hidden`, so the crescent-moon tray is
#     in the panel from login on every desktop. (`luna gui` is single-instance,
#     so clicking the menu entry just raises the already-running tray's window.)
#
# The terminal `luna ask` / `luna chat` / `luna repl` paths still exist as CLI
# commands — they just no longer need their own launchers now the GUI is here.
{ pkgs, ... }:
let
  lunaChatItem = pkgs.makeDesktopItem {
    name = "luna-chat";
    desktopName = "Chat with Luna";
    genericName = "AI assistant";
    comment = "Talk to Luna — a frosted-glass chat with tabs that remember";
    exec = "luna gui";
    terminal = false;
    icon = "applications-internet"; # generic until Luna's own artwork lands
    categories = [ "Utility" "Network" ];
    keywords = [ "luna" "ai" "assistant" "hermes" "chat" ];
  };
in
{
  environment.systemPackages = [ lunaChatItem ];

  # Start the tray (hidden window) at login on any XDG-autostart desktop, so the
  # crescent moon is always in the bar — one click from a conversation.
  environment.etc."xdg/autostart/luna-tray.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Luna
    Comment=Luna chat tray
    Exec=luna gui --hidden
    Icon=applications-internet
    Terminal=false
    Categories=Utility;
    X-GNOME-Autostart-enabled=true
  '';
}
