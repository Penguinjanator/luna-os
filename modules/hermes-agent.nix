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
    # Run as the `luna` user (defined in luna.nix: wheel + passwordless sudo).
    # The module makes ${stateDir}/.hermes owned luna:users mode 2770, and the
    # desktop GUI also runs as luna — so the GUI shares this writable HERMES_HOME
    # instead of hitting EACCES against a root-owned dir. Full root reach comes
    # from luna's passwordless sudo, not from running the daemon as uid 0.
    user = "luna";
    group = "users"; # luna's primary group; must exist or systemd EXIT_GROUP (216)
    createUser = false; # luna is defined in luna.nix, not by the module
    stateDir = "/var/lib/hermes"; # HERMES_HOME = /var/lib/hermes/.hermes
    addToSystemPackages = true; # put the `hermes` CLI on PATH — to talk to her,
    # and so new users can run `hermes setup` to drop in their own keys/profile.

    # Provider SDKs are OPTIONAL extras in hermes, normally lazy-installed at
    # runtime (tools/lazy_deps.py). On NixOS that fails — the Python env lives in
    # the read-only /nix/store (OSError Errno 30) — so `provider=anthropic`
    # can't import `anthropic` and `hermes -z` dies. Pre-build it instead; the
    # module turns this into `package.override { extraDependencyGroups = … }`.
    # hermes's COMPLETE `full` extras set, all pre-built so nothing lazy-installs
    # at runtime (lazy-install can't write the read-only /nix/store). `matrix`
    # (liboqs / post-quantum) and `voice` (faster-whisper / ML) are the heavy two
    # — kept in so matrix + speech are ready without another rebuild. (matrix is
    # Linux-only upstream, which luna-os always is, so it needs no isLinux gate.)
    extraDependencyGroups = [
      "anthropic"      # native Claude provider
      "azure-identity"
      "bedrock"
      "daytona"
      "dingtalk"
      "edge-tts"
      "exa"
      "fal"
      "feishu"
      "firecrawl"
      "hindsight"
      "honcho"
      "matrix"         # matrix protocol (liboqs) — heavier
      "messaging"      # telegram / discord / slack
      "modal"
      "parallel-web"
      "tts-premium"
      "voice"          # faster-whisper STT — heaviest (ML deps)
    ];
  };
}
