# luna.nix — the heart of luna-os.
#
# This is where the AI-native pieces get wired in over time:
#   - the Hermes agent daemon (userspace brain)     -> hermes-agent.nix
#   - the kernel event/intent channel (/dev/hermes)  -> hermes-kernel.nix (later)
#   - the policy cage (polkit/LSM)                    -> hermes-policy.nix (later)
#   - desktop integration (GNOME/KDE/XFCE)            -> hermes-desktop.nix (later)
#
# For now it imports the agent skeleton and drops a marker so we can confirm,
# from inside the booted VM, that our own module is live.
{ ... }:
{
  imports = [
    ./hermes-agent.nix
  ];

  environment.etc."luna-os/release".text = "luna-os 0.0.1 (first light)\n";
}
