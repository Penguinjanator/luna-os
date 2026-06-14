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

  # The installer body lives in ./luna-install.sh (a real bash file, so its
  # arrays + ${} braces don't fight Nix's '' string interpolation). @TARGET@ is
  # replaced with the system config matching this ISO (e.g. luna-os-kde).
  lunaInstall = pkgs.writeShellScriptBin "luna-install"
    (builtins.replaceStrings [ "@TARGET@" ] [ installTarget ]
      (builtins.readFile ./luna-install.sh));
in
{
  # The flake at a fixed path: disko.nix + flake.nix + every module, no clone.
  environment.etc."luna-os".source = self.outPath;

  environment.systemPackages = [ diskoCli lunaInstall ];
}
