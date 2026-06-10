# hermes-agent.nix — the Hermes agent daemon (hermesd) as a systemd service.
#
# DESIGN INVARIANT: the LLM "brain" lives in USERSPACE, never in the kernel.
# An LLM is probabilistic and prompt-injectable, so it must sit OUTSIDE the
# kernel trust boundary and act only through mediated, sandboxed channels.
#
# This is a skeleton: disabled by default and not yet wired to the real agent
# (the hermes-but-better codebase). Enabling it proves the service plumbing;
# the real ExecStart + the kernel /dev/hermes channel come next.
{ config, lib, pkgs, ... }:
let
  cfg = config.services.hermes;
in
{
  options.services.hermes = {
    enable = lib.mkEnableOption "the Hermes agent daemon (hermesd)";
  };

  config = lib.mkIf cfg.enable {
    systemd.services.hermes = {
      description = "Hermes agent daemon (luna-os)";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        # Placeholder process until hermesd exists.
        ExecStart = "${pkgs.coreutils}/bin/sleep infinity";

        # Starter sandbox — the beginning of the policy cage. Expand as the
        # agent gains real (mediated) capabilities.
        DynamicUser = true;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };
  };
}
