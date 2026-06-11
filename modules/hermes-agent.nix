# hermes-agent.nix — Luna's brain, baked into every luna-os.
#
# Imports the Hermes Agent NixOS module (from our pinned `hermes` fork) and
# enables her GATEWAY — the cron/webhook autonomy service (`hermes gateway`).
# So "enabled" means she's autonomously alive, not merely installed.
#
# DESIGN INVARIANT: the LLM brain stays in USERSPACE, never in the kernel — it's
# probabilistic and prompt-injectable, so it sits OUTSIDE the kernel trust
# boundary and acts only through mediated channels (the kernel /dev/hermes + an
# LSM cage come later).
#
# POSTURE — personal "dangerous-af" build: she runs as ROOT with full system
# reach. NixOS generations + rollback are the seatbelt. The blast-radius/approval
# cage is a later, *configurable* layer for when this is handed to other people.
#
# NEXT (step 1b): her secrets (API keys/tokens) via agenix → `environmentFiles`,
# and her Luna profile bundle seeded into `${stateDir}/.hermes`.
{ hermes, ... }:
{
  imports = [ hermes.nixosModules.default ];

  services.hermes-agent = {
    enable = true;
    user = "root";
    group = "root"; # default is "hermes"; with createUser=false that group
    createUser = false; # wouldn't exist → systemd EXIT_GROUP (216). root:root.
    stateDir = "/var/lib/hermes"; # HERMES_HOME = /var/lib/hermes/.hermes
    addToSystemPackages = true; # put the `hermes` CLI on PATH — to talk to her,
    # and so new users can run `hermes setup` to drop in their own keys/profile.
  };
}
