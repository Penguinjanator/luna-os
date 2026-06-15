# luna-launchers.nix — Luna's first native desktop surface: app-menu entries.
#
# Imported by BOTH desktop layers (kde.nix / gnome.nix), never the terminal
# variant — there's no menu without a desktop. Two entries, both reusing the
# `luna` CLI (on PATH via luna-desktop.nix), so there's no second copy of the
# API logic here:
#
#   • "Chat with Luna" → `luna repl` in a terminal (Terminal=true lets each
#     desktop open its own default terminal — konsole on KDE, console on GNOME —
#     so we don't hardcode either). A live, multi-turn, session-threaded chat.
#   • "Ask Luna"       → a zenity prompt → `luna ask` (hermes -z, no dashboard
#     needed) → her answer in a scrollable popup. zenity is GTK but runs fine
#     under Plasma, so one script serves both desktops.
#
# Both also show up in KRunner / the GNOME overview by name — a basic "summon
# Luna" before the deeper KRunner-runner / GNOME-search-provider lands.
#
# NixOS has no system-level xdg.desktopEntries (that's home-manager); the system
# idiom is a makeDesktopItem package dropped into environment.systemPackages.
{ pkgs, lib, ... }:
let
  # "Ask Luna" GUI flow. luna ask = `hermes -z` = the full agent for one turn;
  # it can take a beat, so a pulsating progress runs until it returns, then her
  # answer opens in a text box. Every zenity call is `|| true`-guarded so a
  # cancel (or a closed dialog) never aborts the script under `set -e`.
  askLunaDialog = pkgs.writeShellScriptBin "luna-ask-dialog" ''
    set -eu
    export PATH=${lib.makeBinPath [ pkgs.zenity pkgs.coreutils ]}:$PATH

    question=$(zenity --entry \
      --title="Ask Luna" \
      --text="What do you want to ask Luna?" \
      --width=440) || exit 0
    [ -n "$question" ] || exit 0

    answer=$(mktemp)
    ( luna ask "$question" >"$answer" 2>&1 ) &
    ask_pid=$!

    # Pulse a "thinking…" bar until the ask finishes (the loop ends when the
    # child exits, closing the pipe, which --auto-close then dismisses).
    ( while kill -0 "$ask_pid" 2>/dev/null; do printf '\n'; sleep 0.2; done ) \
      | zenity --progress --pulsate --auto-close --no-cancel \
          --title="Luna" --text="Luna is thinking…" >/dev/null 2>&1 || true
    wait "$ask_pid" || true

    zenity --text-info --title="Luna" --width=640 --height=440 \
      --filename="$answer" >/dev/null 2>&1 || true
    rm -f "$answer"
  '';

  lunaChatItem = pkgs.makeDesktopItem {
    name = "luna-chat"; # → luna-chat.desktop
    desktopName = "Chat with Luna";
    genericName = "AI assistant";
    comment = "Multi-turn conversation with Luna (she remembers the thread)";
    # Terminal=true → the desktop opens its own default terminal for `luna repl`.
    exec = "luna repl";
    terminal = true;
    icon = "utilities-terminal"; # stock icon until Luna's own artwork lands
    categories = [ "Utility" "Network" ];
    keywords = [ "luna" "ai" "assistant" "hermes" "chat" ];
  };

  lunaAskItem = pkgs.makeDesktopItem {
    name = "luna-ask"; # → luna-ask.desktop
    desktopName = "Ask Luna";
    genericName = "AI assistant";
    comment = "Ask Luna a one-shot question and see her answer";
    exec = "luna-ask-dialog";
    terminal = false;
    icon = "dialog-question";
    categories = [ "Utility" ];
    keywords = [ "luna" "ai" "assistant" "hermes" "ask" ];
  };
in
{
  environment.systemPackages = [
    pkgs.zenity
    askLunaDialog
    lunaChatItem
    lunaAskItem
  ];
}
