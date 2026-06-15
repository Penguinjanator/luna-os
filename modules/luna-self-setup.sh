# luna-self-setup — bootstrap the local editable flake this machine rebuilds
# from, so Luna can modify her own OS. Body of a writeShellScriptBin (self-mod.nix
# adds the shebang); @CONFIGPATH@ is replaced at build time with luna.configPath.
#
#   sudo luna-self-setup [kde|gnome|terminal]      (default: kde)
#
# After it runs, `sudo nixos-rebuild switch --flake <path>#<host>` makes the local
# flake your live config; from then on Luna (or you) edits it and runs luna-rebuild.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "luna-self-setup must run as root:  sudo luna-self-setup" >&2
  exit 1
fi

dest="@CONFIGPATH@"
desktop="${1:-kde}"
host="$(hostname)"

case "$desktop" in
  kde | gnome | terminal) ;;
  *) echo "desktop must be one of: kde gnome terminal" >&2; exit 1 ;;
esac

if [ -e "$dest/flake.nix" ]; then
  echo "$dest is already set up (found $dest/flake.nix). Edit it, then luna-rebuild." >&2
  exit 1
fi

echo ">>> generating $dest from this machine ..."
mkdir -p "$dest"
nixos-generate-config --show-hardware-config > "$dest/hardware-configuration.nix"

cat > "$dest/flake.nix" <<EOF
{
  description = "$host — self-modifiable luna-os";

  inputs.luna-os.url = "github:Penguinjanator/luna-os";
  inputs.nixpkgs.follows = "luna-os/nixpkgs";

  outputs = { nixpkgs, luna-os, ... }: {
    nixosConfigurations."$host" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        luna-os.nixosModules.luna
$( [ "$desktop" = "terminal" ] || echo "        luna-os.nixosModules.$desktop" )
        ./hardware-configuration.nix
        ./local.nix
      ];
    };
  };
}
EOF

cat > "$dest/local.nix" <<EOF
# local.nix — Luna's own space. She edits this (and anything under $dest), then
# runs luna-rebuild. NixOS generations + this repo's git history are the
# two-layer rollback. Add your goodies here (luna-os's examples/daily/goodies.nix
# is a tasteful starting set).
{ ... }:
{
  networking.hostName = "$host";
  boot.loader.systemd-boot.enable = true;      # assumes UEFI — edit for BIOS
  boot.loader.efi.canTouchEfiVariables = true;
  system.stateVersion = "25.05";
}
EOF

git -C "$dest" init -q
git -C "$dest" add -A
git -C "$dest" -c user.email=luna@localhost -c user.name=Luna commit -qm "luna-os: initial self-mod config"
chown -R luna:users "$dest"

echo
echo "  $dest is ready (a luna-owned git repo). Make it your live config:"
echo "    sudo nixos-rebuild switch --flake $dest#$host"
echo "  From then on, edit $dest and apply with:  luna-rebuild"
echo "  (review local.nix first — adjust the bootloader if this box isn't UEFI.)"
