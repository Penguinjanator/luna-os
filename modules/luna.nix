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
{ pkgs, ... }:
{
  imports = [
    ./hermes-agent.nix
    ./dev.nix
  ];

  environment.etc."luna-os/release".text = "luna-os 0.0.1 (first light)\n";

  # A genuinely useful base userland so luna-os — and crucially both live ISOs —
  # isn't a bare minimal build. Every variant (daily, lab, and the two ISOs)
  # imports this module, so this is the one place to define the shared toolset.
  # Deliberately lightweight CLI only — no desktop yet (that arrives later as
  # hermes-desktop.nix). Heavy/special-purpose tooling stays out of the base.
  environment.systemPackages = with pkgs; [
    # editors
    vim
    nano
    # version control
    git
    # shell & terminal comfort
    tmux
    htop
    tree
    ripgrep
    fd
    jq
    bat
    file
    which
    # networking
    curl
    wget
    dnsutils # dig, nslookup
    iproute2 # ip, ss
    iputils # ping
    tcpdump
    ethtool
    nmap
    rsync
    # archives
    unzip
    zip
    p7zip
    # disk & hardware inspection
    parted
    gptfdisk # sgdisk
    dosfstools
    pciutils # lspci
    usbutils # lsusb
    lshw
    smartmontools
    lsof
    psmisc # pstree, killall
    strace
  ];
}
