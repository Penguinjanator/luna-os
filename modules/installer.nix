# installer.nix — turns a live ISO into a self-contained luna-os installer.
#
# Imported ONLY by the `iso` target (live images). It:
#   - bakes the whole flake source (this repo) to /etc/luna-os, so disko.nix and
#     the flake are already present — no `git clone`;
#   - puts the `disko` CLI on PATH;
#   - ships a one-shot `luna-install` that formats the disk (from disko.nix) and
#     installs the system config that matches this ISO's kernel + desktop.
#
# So the whole install is:  boot the ISO  ->  sudo luna-install  ->  reboot.
{ pkgs, self, disko, installTarget, ... }:
let
  diskoCli = disko.packages.${pkgs.stdenv.hostPlatform.system}.disko;

  lunaInstall = pkgs.writeShellScriptBin "luna-install" ''
    set -euo pipefail

    if [ "$(id -u)" -ne 0 ]; then
      echo "luna-install must run as root:  sudo luna-install"
      exit 1
    fi

    flake=/etc/luna-os
    target=${installTarget}
    disk=/dev/sda   # matches disko.nix — change BOTH for NVMe (/dev/nvme0n1) etc.

    echo
    echo "  luna-install"
    echo "  ============"
    echo "  This ERASES $disk and installs luna-os ($target) onto it."
    echo
    lsblk -dn -o NAME,SIZE,MODEL "$disk" 2>/dev/null || true
    echo
    read -rp "  Type YES to wipe $disk and install: " confirm
    if [ "$confirm" != "YES" ]; then
      echo "  Aborted — nothing changed."
      exit 1
    fi

    echo
    echo ">>> Partitioning + formatting $disk with disko ..."
    disko --mode disko "$flake/disko.nix"

    echo
    echo ">>> Installing luna-os ($target) — this builds/fetches the system ..."
    nixos-install --flake "$flake#$target" --no-root-passwd

    # If this ISO carries the git+ssh deploy key (a keyed build), copy it into
    # the installed system so it can self-update (nixos-rebuild over git+ssh)
    # without a manual key drop. Lands as a plain 0600 root file on the new disk
    # — NOT in the world-readable nix store.
    key=/root/.ssh/luna-os_ed25519
    if [ -f "$key" ]; then
      install -d -m 700 /mnt/root/.ssh
      install -m 600 "$key" /mnt/root/.ssh/luna-os_ed25519
      echo ">>> deploy key copied into the installed system (/root/.ssh)"
    fi

    echo
    echo "  Done. Next:"
    echo "    1. Power off and remove the ISO from the VM."
    echo "    2. Boot from the disk; log in as luna (password: luna)."
    echo "    3. Drop her .hermes bundle into /var/lib/hermes/.hermes."
  '';
in
{
  # The flake at a fixed path: disko.nix + flake.nix + every module, no clone.
  environment.etc."luna-os".source = self.outPath;

  environment.systemPackages = [ diskoCli lunaInstall ];
}
