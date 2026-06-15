# hermes-dashboard.nix — Luna's dashboard API as an always-on service.
#
# `hermes dashboard` is the FastAPI server on 127.0.0.1:9119 that backs the
# native clients: `luna chat` streams through its POST /api/chat, `luna status`
# / `luna sessions` read its /api/*. Until now it had to be started by hand
# (`hermes dashboard &`) with a token exported manually — so a fresh boot left
# `luna chat` dead with "connection refused". This boots it with the OS.
#
# The auth knot: the dashboard reads HERMES_DASHBOARD_SESSION_TOKEN from its
# environment (else it mints a random one no client can guess — web_server.py
# `_SESSION_TOKEN`); the `luna` CLI must present the SAME token. So we mint ONE
# stable per-machine token into an EnvironmentFile that the service consumes and
# luna's shells source — and `luna` reads the file directly as a fallback
# (config.rs) for non-login surfaces (the KDE/GNOME launchers). Zero-setup, and
# the token is generated at runtime, never baked into the world-readable store.
{ config, lib, pkgs, ... }:
let
  cfg = config.services.hermes-agent;

  # The exact package the gateway runs (base + our pre-built provider extras).
  # Mirrors the hermes module's internal `effectivePackage`; nix dedups it, so
  # this resolves to the same derivation, not a second build.
  hermesPkg =
    if cfg.extraPythonPackages == [ ] && cfg.extraDependencyGroups == [ ]
    then cfg.package
    else cfg.package.override { inherit (cfg) extraPythonPackages extraDependencyGroups; };

  stateDir = cfg.stateDir;                  # /var/lib/hermes
  tokenFile = "${stateDir}/dashboard.env";  # HERMES_DASHBOARD_SESSION_TOKEN=…
in
{
  # Mint the shared session token ONCE per machine (kept across reboots so
  # already-open luna shells stay valid). Done in activation — before any
  # service starts — the same mechanism the hermes module uses to seed .env.
  # Ordered after hermes-agent-setup so ${stateDir} already exists (2770 luna).
  # openssl is in the base userland (luna.nix). 0640 luna:users: luna reads it,
  # the world does not.
  system.activationScripts."luna-dashboard-token" =
    lib.stringAfter [ "hermes-agent-setup" ] ''
      if [ ! -s ${tokenFile} ]; then
        umask 027
        printf 'HERMES_DASHBOARD_SESSION_TOKEN=%s\n' \
          "$(${pkgs.openssl}/bin/openssl rand -hex 32)" > ${tokenFile}
        chown ${cfg.user}:${cfg.group} ${tokenFile}
        chmod 0640 ${tokenFile}
      fi
    '';

  # The always-on dashboard server. Mirrors the gateway service's identity,
  # HERMES_HOME, and hardening (hermes nix/nixosModules.nix), but runs the
  # `dashboard` subcommand and pulls the token from the EnvironmentFile.
  systemd.services.hermes-dashboard = {
    description = "Luna's dashboard API (hermes dashboard) — local gateway for luna chat/status";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    environment = {
      HOME = stateDir;
      HERMES_HOME = "${stateDir}/.hermes";
      HERMES_MANAGED = "true";
    };

    serviceConfig = {
      User = cfg.user;
      Group = cfg.group;
      WorkingDirectory = cfg.workingDirectory;
      # The per-machine token (HERMES_DASHBOARD_SESSION_TOKEN). The activation
      # script guarantees this file exists before the unit starts, so no `-`
      # prefix: a missing file SHOULD fail loudly rather than silently mint a
      # random token the CLI can't match.
      EnvironmentFile = tokenFile;
      # --no-open: headless, never reach for a browser. --skip-build: serve the
      # store's pre-built web dist (the wrapper sets HERMES_WEB_DIST) instead of
      # running npm at startup. The API (/api/chat) — all `luna` needs — is up
      # regardless of the SPA.
      ExecStart = lib.concatStringsSep " " [
        "${hermesPkg}/bin/hermes"
        "dashboard"
        "--host" "127.0.0.1"
        "--port" "9119"
        "--no-open"
        "--skip-build"
      ];
      Restart = "on-failure";
      RestartSec = 5;

      # Shared-state: files the dashboard creates (session DB) should be
      # group-writable so the gateway service (same group) can touch them too.
      UMask = "0007";

      # Hardening — mirror the gateway service.
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadWritePaths = [ stateDir cfg.workingDirectory ];
      PrivateTmp = true;
    };

    path = [ hermesPkg pkgs.bash pkgs.coreutils pkgs.git ];
  };

  # Hand luna's interactive shells the SAME token so `luna chat` / `luna status`
  # work with zero setup in a terminal. The file is luna:users 0640; the guard
  # makes this a silent no-op for anyone who can't read it. (Non-interactive
  # surfaces — KDE/GNOME launchers — don't hit this path; `luna` reads the file
  # itself, see luna-desktop config.rs.)
  environment.interactiveShellInit = ''
    if [ -r ${tokenFile} ]; then
      set -a; . ${tokenFile}; set +a
    fi
  '';
}
