# goodies.nix — a tasteful NixOS daily-driver on top of Luna.
#
# Luna's modules already give you: the agent + dashboard, the `luna` CLI + chat
# widget, the `luna` user (passwordless-sudo wheel), a big base userland, unfree
# packages, nh + auto-GC, and the SSH server. This file adds the everyday desktop
# niceties. It's a STARTING POINT — rip out what you don't want, add what you do.
{ pkgs, ... }:
{
  # ── Boot ────────────────────────────────────────────────────────────────
  # systemd-boot on UEFI. (If your hardware-configuration.nix or a Luna disk
  # module already sets a bootloader, drop this block.)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 3;

  # ── Identity / locale ─────────────────────────────────────────────────────
  networking.hostName = "my-box";          # ← change me
  time.timeZone = "America/New_York";       # ← change me
  i18n.defaultLocale = "en_US.UTF-8";

  # The `luna` user comes from Luna's module (initialPassword "luna" — change it!).
  # Want your OWN login too? Uncomment and tweak:
  # users.users.you = {
  #   isNormalUser = true;
  #   description = "You";
  #   extraGroups = [ "wheel" "networkmanager" ];
  #   initialPassword = "changeme";
  # };

  # ── Networking ──────────────────────────────────────────────────────────
  networking.networkmanager.enable = true;

  # ── Audio (PipeWire) ──────────────────────────────────────────────────────
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # ── Hardware niceties ─────────────────────────────────────────────────────
  hardware.bluetooth.enable = true;
  hardware.graphics.enable = true;          # OpenGL / Vulkan
  services.fwupd.enable = true;             # firmware updates
  zramSwap.enable = true;                   # compressed RAM swap

  # ── Printing + network discovery ──────────────────────────────────────────
  services.printing.enable = true;
  services.avahi = { enable = true; nssmdns4 = true; openFirewall = true; };

  # ── Shell + prompt ────────────────────────────────────────────────────────
  programs.fish.enable = true;
  programs.starship.enable = true;
  # users.users.luna.shell = pkgs.fish;     # make fish luna's login shell

  # ── Browser + dev comforts ────────────────────────────────────────────────
  programs.firefox.enable = true;
  programs.direnv.enable = true;            # per-project envs (pairs with nix)

  # ── Apps ──────────────────────────────────────────────────────────────────
  # Most CLI tooling is already in Luna's base userland. These are GUI extras.
  environment.systemPackages = with pkgs; [
    mpv vlc            # media
    keepassxc          # passwords
    libreoffice-fresh  # office
    thunderbird        # mail
    signal-desktop     # chat
    gimp               # images
    spotify            # music (unfree — allowed by Luna's module)
  ];

  # Flatpak for the long tail of apps not packaged in nixpkgs.
  services.flatpak.enable = true;

  # ── Fonts ─────────────────────────────────────────────────────────────────
  fonts.packages = with pkgs; [
    noto-fonts noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono nerd-fonts.fira-code
  ];

  # ── Opt-in heavyweights (uncomment if you want them) ──────────────────────
  # programs.steam.enable = true;           # gaming
  # virtualisation.docker.enable = true;    # containers
  # programs.nix-ld.enable = true;          # run arbitrary prebuilt binaries

  # ── Nix housekeeping ──────────────────────────────────────────────────────
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  # (Generation GC is already handled by Luna's module via nh.clean — don't also
  # enable nix.gc.automatic here, or the two fight.)

  # The release you first installed on — DON'T bump this casually (it pins
  # stateful defaults). See https://nixos.org/manual → stateVersion.
  system.stateVersion = "25.05";
}
