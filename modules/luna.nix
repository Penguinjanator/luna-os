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

  # Luna is ONE root-capable user across every variant — the console, the desktop
  # session (autologin), and the Hermes agent service all run as `luna`. wheel +
  # passwordless sudo = effective root without the fragility of a literal-root
  # graphical session. Because the GUI runs as luna AND the agent runs as luna,
  # they share one writable HERMES_HOME (the module makes it 2770 luna-owned) —
  # no permission split, one Luna. Defined here (not configuration.nix) so the
  # live ISOs get the user too.
  users.users.luna = {
    isNormalUser = true;
    initialPassword = "luna"; # dev only — replace before anything real
    extraGroups = [ "wheel" ];
  };
  security.sudo.wheelNeedsPassword = false; # dangerous-af: frictionless root

  environment.etc."luna-os-release".text = "luna-os 0.0.1 (first light)\n";

  # LUNA-OS self-update plumbing. The flake fetches its private inputs (kernel +
  # hermes) over git+ssh through the `github-penguin` host alias. Baking the
  # alias into the OS means a deployed box self-updates with zero config: drop
  # the read-only key at /root/.ssh/luna-os_ed25519 and `nix flake update` /
  # `nixos-rebuild --flake` just work. The KEY is never baked in (it's a secret,
  # dropped per-machine like ~/.hermes); only this non-secret alias is.
  programs.ssh.extraConfig = ''
    Host github-penguin
        HostName github.com
        User git
        IdentityFile /root/.ssh/luna-os_ed25519
        IdentitiesOnly yes
  '';

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
