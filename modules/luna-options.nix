# luna-options.nix — knobs for the maintainer-specific identity defaults, so a
# public consumer of nixosModules.luna isn't forced to inherit this machine's
# personality. Defaults preserve the "dangerous-af" daily-driver behaviour; flip
# them off for a safer / cleaner install. (Referenced by luna.nix.)
{ lib, ... }:
{
  options.luna = {
    passwordlessSudo = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Give the `wheel` group PASSWORDLESS sudo. This is the "dangerous-af"
        default that turns luna's wheel membership into effective root -- how the
        (un-sandboxed) agent reaches the whole system. Set false for a safer
        install where the agent has only the user's own privileges.
      '';
    };

    deployAlias = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Bake the maintainer's `github-penguin` SSH alias into the system. It was
        used to self-update luna-os over the private luna-os_ed25519 key in the
        git+ssh era; harmless to anyone else (the key won't exist) but vestigial
        now that luna-os is consumed publicly over `github:`. Set false to omit it.
      '';
    };
  };
}
