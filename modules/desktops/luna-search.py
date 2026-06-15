#!/usr/bin/env python3
"""luna-search — D-Bus bridge that lets you ask Luna from the desktop search bar.

One program, two interfaces (pick with argv[1]):
  krunner       -> org.kde.krunner1 at /runner          (KDE KRunner)
  gnome-search  -> org.gnome.Shell.SearchProvider2       (GNOME overview)

Both surface a single "Ask Luna: <query>" result as you type; activating it hands
the query to `luna-ask-dialog` (the zenity ask flow in luna-launchers.nix), which
runs `luna ask` and shows her answer. The agent turn can take many seconds, so it
runs DETACHED -- the D-Bus methods return immediately and never block the shell.

Started on demand via D-Bus activation (.service files installed by
luna-search.nix); it just sits on a GLib main loop owning its bus name.
"""
import os
import subprocess
import sys

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

# NixOS system profile: the stable absolute home of luna-ask-dialog / luna, so
# the spawn resolves regardless of the (minimal) D-Bus activation environment.
_SYSTEM_BIN = "/run/current-system/sw/bin"

_KRUNNER_IFACE = "org.kde.krunner1"
_SEARCH_IFACE = "org.gnome.Shell.SearchProvider2"
_PREFIX = "ask:"


def _ask_luna(query):
    """Hand the query to the GUI ask flow, detached (never block the caller)."""
    query = (query or "").strip()
    if not query:
        return
    env = dict(os.environ)
    env["PATH"] = _SYSTEM_BIN + os.pathsep + env.get("PATH", "")
    try:
        subprocess.Popen(
            ["luna-ask-dialog", query],
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError:
        pass


def _decode(result_id):
    """Recover the query from an "ask:<query>" result id."""
    return result_id[len(_PREFIX):] if result_id.startswith(_PREFIX) else result_id


class KRunnerService(dbus.service.Object):
    """org.kde.krunner1 — KDE KRunner D-Bus runner (Match/Actions/Run)."""

    def __init__(self):
        bus = dbus.SessionBus()
        self._name = dbus.service.BusName("org.luna.Runner", bus)
        super().__init__(bus, "/runner")

    @dbus.service.method(_KRUNNER_IFACE, in_signature="s", out_signature="a(sssida{sv})")
    def Match(self, query):
        q = (query or "").strip()
        if len(q) < 2:
            return []
        # (id, text, iconName, categoryRelevance, relevance, properties)
        props = dbus.Dictionary({"subtext": "Run it through Luna"}, signature="sv")
        return [(
            _PREFIX + q,
            "Ask Luna: " + q,
            "im-user",
            dbus.Int32(70),    # CategoryRelevance::High (0..100)
            dbus.Double(1.0),
            props,
        )]

    @dbus.service.method(_KRUNNER_IFACE, in_signature="", out_signature="a(sss)")
    def Actions(self):
        return []

    @dbus.service.method(_KRUNNER_IFACE, in_signature="ss", out_signature="")
    def Run(self, match_id, action_id):
        _ask_luna(_decode(match_id))


class SearchProviderService(dbus.service.Object):
    """org.gnome.Shell.SearchProvider2 — GNOME overview search."""

    def __init__(self):
        bus = dbus.SessionBus()
        self._name = dbus.service.BusName("org.luna.SearchProvider", bus)
        super().__init__(bus, "/org/luna/SearchProvider")

    @staticmethod
    def _result_ids(terms):
        q = " ".join(terms).strip()
        # Encode the query into the id: GetResultMetas only gets ids back, so the
        # id must carry enough to both render and activate the result.
        return [_PREFIX + q] if len(q) >= 2 else []

    @dbus.service.method(_SEARCH_IFACE, in_signature="as", out_signature="as")
    def GetInitialResultSet(self, terms):
        return self._result_ids(terms)

    @dbus.service.method(_SEARCH_IFACE, in_signature="asas", out_signature="as")
    def GetSubsearchResultSet(self, previous_results, terms):
        return self._result_ids(terms)

    @dbus.service.method(_SEARCH_IFACE, in_signature="as", out_signature="aa{sv}")
    def GetResultMetas(self, ids):
        metas = []
        for rid in ids:
            metas.append(dbus.Dictionary({
                "id": dbus.String(rid),
                "name": dbus.String("Ask Luna"),
                "description": dbus.String(_decode(rid)),
                "gicon": dbus.String("im-user"),
            }, signature="sv"))
        return metas

    @dbus.service.method(_SEARCH_IFACE, in_signature="sasu", out_signature="")
    def ActivateResult(self, result_id, terms, timestamp):
        _ask_luna(" ".join(terms).strip() or _decode(result_id))

    @dbus.service.method(_SEARCH_IFACE, in_signature="asu", out_signature="")
    def LaunchSearch(self, terms, timestamp):
        _ask_luna(" ".join(terms))


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    DBusGMainLoop(set_as_default=True)
    if mode == "krunner":
        KRunnerService()
    elif mode == "gnome-search":
        SearchProviderService()
    else:
        sys.stderr.write("usage: luna-search {krunner|gnome-search}\n")
        return 2
    GLib.MainLoop().run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
