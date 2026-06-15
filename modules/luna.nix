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
{ config, lib, pkgs, ... }:
{
  imports = [
    ./luna-options.nix
    ./self-mod.nix
    ./hermes-agent.nix
    ./hermes-dashboard.nix
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
  # luna.passwordlessSudo (default on) — the "dangerous-af" frictionless root that
  # gives the agent effective root. A public consumer can flip it off.
  security.sudo.wheelNeedsPassword = !config.luna.passwordlessSudo;

  # Allow unfree packages (Obsidian and friends). Personal build — we accept
  # proprietary GUI apps. Set here in the shared base so it also covers the live
  # ISOs, not just installed systems (configuration.nix is system-target only).
  nixpkgs.config.allowUnfree = true;

  environment.etc."luna-os-release".text = "luna-os 0.0.1 (first light)\n";

  # LUNA-OS self-update plumbing. The flake fetches its private inputs (kernel +
  # hermes) over git+ssh through the `github-penguin` host alias. Baking the
  # alias into the OS means a deployed box self-updates with zero config: drop
  # the read-only key at /root/.ssh/luna-os_ed25519 and `nix flake update` /
  # `nixos-rebuild --flake` just work. The KEY is never baked in (it's a secret,
  # dropped per-machine like ~/.hermes); only this non-secret alias is.
  programs.ssh.extraConfig = lib.mkIf config.luna.deployAlias ''
    Host github-penguin
        HostName github.com
        User git
        IdentityFile /root/.ssh/luna-os_ed25519
        IdentitiesOnly yes
  '';

  # nh (nix-helper): friendlier `nh os switch` + automatic generation cleanup.
  # clean.* runs a GC on a timer keeping recent generations — disk hygiene that
  # keeps the store (and, in WSL, the ext4.vhdx) from bloating over time.
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    # NH_OS_FLAKE intentionally unset: no universal luna-os flake path
    # (/etc/luna-os exists only on the live ISOs, not installed systems). Point
    # it at your checkout for a default: programs.nh.flake = "/home/luna/luna-os";
  };

  # SSH server — remote login + scp/sftp into the box. (luna's password is set
  # above; harden/lock it down before any real network exposure.)
  services.openssh.enable = true;

  # This kernel lacks the iptables rpfilter module, so NixOS's reverse-path check
  # fails the firewall at start (`RULE_APPEND ... No such file`, exit 4). Skip
  # that one rule; the firewall otherwise runs normally.
  networking.firewall.checkReversePath = false;

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
    ltrace # library-call trace (pairs with strace)
    # security / crypto
    openssl # `openssl rand`, certs, hashing — the thing that was missing
    gnupg # gpg
    pinentry-curses # gpg passphrase prompt on the console
    # remote access
    openssh # ssh / scp / sftp / ssh-keygen client (server = services.openssh)
    # more networking
    nettools # ifconfig, netstat, route, hostname
    netcat-gnu # nc
    socat
    mtr # combined traceroute + ping
    traceroute
    whois
    # text, files, pagers, archives
    less # default pager (man, git, systemctl use it)
    diffutils # diff, cmp
    patch
    gnumake # make — basic build glue
    zstd
    xz # xz / unxz
    ncdu # interactive disk-usage browser
    pv # pipe progress meter
    # editors / shells
    neovim
    # system / hardware
    dmidecode
    lm_sensors # `sensors`
    util-linux # lsblk, fdisk, hexdump, uuidgen, etc. (explicit; mostly in base)
  ];
}
