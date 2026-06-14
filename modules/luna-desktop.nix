# luna-desktop.nix — Luna's native client(s), built from the pinned luna-desktop
# repo. For now: the `luna` Rust CLI on PATH (luna ask / chat / status /
# sessions). The KDE plasmoid + GNOME extension get added here as they land.
#
# Imported by EVERY variant (like luna.nix) so `luna` is always available — the
# desktop surfaces shell out to it. Built with buildRustPackage from the pinned
# repo's cli/ crate; its committed Cargo.lock pins the deps reproducibly.
{ pkgs, luna-desktop, ... }:
let
  luna-cli = pkgs.rustPlatform.buildRustPackage {
    pname = "luna-cli";
    version = "0.1.0";
    src = "${luna-desktop}/cli";
    cargoLock.lockFile = "${luna-desktop}/cli/Cargo.lock";
  };
in
{
  environment.systemPackages = [ luna-cli ];
}
