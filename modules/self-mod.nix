# self-mod.nix — the loop that lets Luna rewrite her own OS.
#
# The machine rebuilds from a LOCAL, luna-editable flake (luna.configPath,
# default /etc/luna) that imports luna-os's nixosModules + this box's hardware +
# her own local.nix. The loop:
#
#     edit a file under /etc/luna  ->  luna-rebuild  ->  the change is live
#
# NixOS generations + the /etc/luna git history are the two-layer rollback. Luna
# runs as `luna` (who owns /etc/luna) with passwordless sudo, so she has both the
# write access and the privilege to apply it. The installer materialises /etc/luna
# on fresh installs; `luna-self-setup` bootstraps it on an existing machine.
{ config, lib, pkgs, ... }:
let
  cfg = config.luna;

  # The "apply my edits" command, for Luna or you:
  #   luna-rebuild            -> nixos-rebuild switch from the local flake
  #   luna-rebuild boot       -> ...any nixos-rebuild subcommand/flags pass through
  lunaRebuild = pkgs.writeShellScriptBin "luna-rebuild" ''
    set -eu
    cfg="''${LUNA_OS_CONFIG:-${cfg.configPath}}"
    host="$(hostname)"
    sub="''${1:-switch}"; [ "$#" -gt 0 ] && shift || true
    echo ">>> luna-rebuild: nixos-rebuild $sub --flake $cfg#$host" >&2
    exec sudo nixos-rebuild "$sub" --flake "$cfg#$host" "$@"
  '';

  # Bootstrap the local editable flake on an EXISTING machine (the installer does
  # this for fresh installs). Real .sh file so its heredocs don't fight Nix.
  lunaSelfSetup = pkgs.writeShellScriptBin "luna-self-setup"
    (builtins.replaceStrings [ "@CONFIGPATH@" ] [ cfg.configPath ]
      (builtins.readFile ./luna-self-setup.sh));
in
{
  options.luna.configPath = lib.mkOption {
    type = lib.types.str;
    default = "/etc/luna";
    description = ''
      Path to the LOCAL, editable flake this machine rebuilds from -- the heart of
      Luna's self-modification: she edits files here and runs `luna-rebuild`, with
      NixOS generations + git history as the rollback. The installer materialises
      it; `luna-self-setup` bootstraps it on an existing machine. Point it at your
      own checkout (e.g. /home/luna/luna) if you keep your config elsewhere.
    '';
  };

  config = {
    environment.systemPackages = [ lunaRebuild lunaSelfSetup ];
    # So Luna's shells (and anything she spawns) know where her config lives.
    environment.variables.LUNA_OS_CONFIG = cfg.configPath;
  };
}
