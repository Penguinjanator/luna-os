# dev-ssh-key.nix — DEV-ONLY, opt-in: bake the git+ssh deploy key into a live ISO
# so a freshly-booted image can run `luna-install` (which fetches the private
# `hermes` / lab-kernel inputs over git+ssh) WITHOUT manually pasting the key.
#
# Opt-in by build invocation, never by default:
#
#     LUNA_BAKE_KEY=$HOME/.ssh/luna-os_ed25519 nix build --impure .#iso-kde
#
# flake.nix only imports this module when that env var is non-empty, so a normal
# `nix build .#iso-kde` stays pure and keyless. The key path comes from the env
# var, so nothing personal/secret is hard-coded here and the key never enters git.
#
# SECURITY — read this: the key is copied into the image's nix store, which is
# WORLD-READABLE. The 0600 on /root/.ssh/luna-os_ed25519 is cosmetic — anyone who
# can read the ISO can `cat` the key straight out of /nix/store. So a keyed ISO is
# ONLY for local testing on your own machine. Never distribute one; rotate the key
# before any real build. To ship a real keyless ISO, just build without the env var.
{ lib, ... }:
let
  keyPath = builtins.getEnv "LUNA_BAKE_KEY";
in
{
  assertions = [{
    assertion = keyPath != "" && builtins.pathExists keyPath;
    message = "dev-ssh-key.nix: LUNA_BAKE_KEY='${keyPath}' but no key file exists there "
      + "(and remember to build with --impure so the env var is visible).";
  }];

  # Install the key as root with tight perms on first activation (boot). The store
  # copy referenced here is world-readable; this 0600 copy is the one ssh will use.
  system.activationScripts.lunaDevSshKey = ''
    install -d -m 700 -o root -g root /root/.ssh
    install -m 600 -o root -g root \
      ${builtins.path { path = keyPath; name = "luna-os_ed25519"; }} \
      /root/.ssh/luna-os_ed25519
  '';
}
