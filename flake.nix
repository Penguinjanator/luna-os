{
  description = "luna-os: an AI-native NixOS, home to the Hermes agent";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Our kernel source = Penguinjanator/luna-os-kernel (private). Fetched over
    # git+ssh through the `github-penguin` host alias (~/.ssh/config -> the
    # luna-os_ed25519 key). This URL is baked into the OS, so a deployed machine
    # self-updates the same way: drop the key in, `nix flake update`. No access
    # token anywhere. ?ref=main tracks the stable branch.
    luna-kernel = {
      url = "git+ssh://git@github-penguin/Penguinjanator/luna-os-kernel?ref=main";
      flake = false;
    };

    # Luna's brain: our fork of Nous Research's Hermes Agent. Same git+ssh path
    # so the OS can pull upstream merges itself (`nix flake update hermes`).
    # NB: intentionally NOT following our nixpkgs — she builds against her own
    # locked nixpkgs (uv2nix), matching how upstream tests her.
    #
    # Iterating on UNCOMMITTED local changes? git+ssh fetches the pushed commit,
    # so override per-build instead of editing this file:
    #   nix build .#iso-lab \
    #     --override-input hermes      git+file:///home/potato/work-code/hermes-but-better \
    #     --override-input luna-kernel git+file:///home/potato/work-code/linux-master
    hermes.url = "git+ssh://git@github-penguin/Penguinjanator/hermes-but-better?ref=main";

    # disko: declarative disk partitioning. Drives the baked-in `luna-install`
    # one-shot installer (disko.nix + modules/disk.nix). Follows our nixpkgs.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # luna-os is built as a MATRIX, not a handful of hand-written systems:
  #
  #     kernel   {stock, lab}      x  desktop {terminal, gnome, kde}  x  target {system, iso}
  #
  # `stock`  = the nixpkgs kernel (boots real hardware today).
  # `lab`    = our custom 7.1.0-rc7 kernel (modules/hermes-kernel.nix).
  # desktop  = the "flavor" — exactly how upstream NixOS ships its installers
  #            (separate per-desktop images); terminal = no desktop.
  # target   = an installable/VM `system`, or a live `iso`.
  #
  # Every point shares modules/luna.nix (identity + base userland + dev langs),
  # so the whole grid is generated from one `mkSystem` function below. Names stay
  # backward compatible: luna-os, luna-os-lab, luna-os-iso, luna-os-lab-iso are
  # the terminal points; desktops add a -gnome / -kde infix.
  outputs =
    { self, nixpkgs, luna-kernel, hermes, disko, ... }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;

      isoProfile = "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix";

      # ---- the three axes of the matrix ----
      kernels = [ "stock" "lab" ];
      desktops = [ "terminal" "gnome" "kde" ];
      targets = [ "system" "iso" ];

      # Desktop layers; "terminal" adds nothing. (The Nous Electron desktop app
      # was removed: it bootstraps and OWNS its own backend, which fights luna-os's
      # always-on gateway. Luna's interface will be NATIVE KDE/GNOME integration —
      # a Plasma plasmoid/KRunner plugin, a GNOME Shell extension — talking to the
      # gateway, not a wrapped webapp.)
      desktopLayer = {
        terminal = [ ];
        gnome = [ ./modules/desktops/gnome.nix ];
        kde = [ ./modules/desktops/kde.nix ];
      };

      # Kernel layers; "stock" = nixpkgs kernel, "lab" = our 7.1.0-rc7.
      kernelLayer = {
        stock = [ ];
        lab = [ ./modules/hermes-kernel.nix ];
      };

      # NOTE: lab ISOs run the default systemd-initrd — no scripted-stage-1 pin.
      # They once needed scripted stage-1 to boot, but that only masked a kernel
      # .config gap: NixOS mounts the live store with `-o threads=multi`, an option
      # that exists only when CONFIG_SQUASHFS_CHOICE_DECOMP_BY_MOUNT=y. With that
      # enabled in hermes-kernel.config, systemd-initrd assembles the store mount
      # fine, so the workaround is gone (scripted initrd is deprecated anyway).

      # Live desktop ISOs autologin the installer's `nixos` user straight into the
      # session — blank-password GUI login is awkward otherwise. (Matches how
      # NixOS's own graphical installer images behave.)
      isoDesktopAutologin = {
        services.displayManager.autoLogin = {
          enable = true;
          user = "luna"; # the one root-capable user (defined in modules/luna.nix)
        };
      };

      # Build one nixosSystem for a {kernel, desktop, target} point in the matrix.
      mkSystem = { kernel, desktop, target }:
        lib.nixosSystem {
          inherit system;
          # Luna's brain (hermes) goes to every variant; the kernel source only
          # to the lab variants that build our custom kernel.
          specialArgs = { inherit hermes self; }
            // lib.optionalAttrs (kernel == "lab") { inherit luna-kernel; }
            # ISOs are self-contained installers: hand them disko + the name of
            # the system target to install (luna-os-kde-iso installs luna-os-kde).
            // lib.optionalAttrs (target == "iso") {
                 inherit disko;
                 installTarget = sysName { inherit kernel desktop; target = "system"; };
               };
          modules =
            # A "system" is the installable/VM base; an "iso" is the live image.
            # System targets also layer in the disk + bootloader (modules/disk.nix)
            # so they install to a real disk: `nixos-install --flake .#luna-os-kde`.
            (if target == "iso" then [ isoProfile ] else [ ./configuration.nix ./modules/disk.nix ])
            ++ [ ./modules/luna.nix ]
            ++ kernelLayer.${kernel}
            ++ desktopLayer.${desktop}
            ++ lib.optional (target == "iso" && desktop != "terminal") isoDesktopAutologin
            # Headless variants re-close the user-namespace surface; desktop
            # variants keep it (Chromium's sandbox needs unprivileged userns).
            ++ lib.optional (desktop == "terminal") ./modules/harden-userns.nix
            # Live ISOs are self-contained installers: bake the flake to
            # /etc/luna-os + ship `disko` and a `luna-install` one-shot.
            ++ lib.optional (target == "iso") ./modules/installer.nix
            # A headless VM of a desktop is pointless — give desktop VM variants a
            # real graphical window (no effect on the ISO or installed system).
            ++ lib.optional (target == "system" && desktop != "terminal") {
              virtualisation.vmVariant.virtualisation.graphics = lib.mkForce true;
            };
        };

      # luna-os[-lab][-gnome|-kde][-iso]
      sysName = { kernel, desktop, target }:
        "luna-os"
        + lib.optionalString (kernel == "lab") "-lab"
        + lib.optionalString (desktop != "terminal") "-${desktop}"
        + lib.optionalString (target == "iso") "-iso";

      # vm[-lab][-gnome|-kde] / iso[-lab][-gnome|-kde]
      pkgName = prefix: { kernel, desktop }:
        prefix
        + lib.optionalString (kernel == "lab") "-lab"
        + lib.optionalString (desktop != "terminal") "-${desktop}";

      # every {kernel, desktop, target} point of the grid
      matrix = lib.concatMap
        (kernel: lib.concatMap
          (desktop: map (target: { inherit kernel desktop target; }) targets)
          desktops)
        kernels;

      # every {kernel, desktop} point (used to name the build targets)
      flavors = lib.concatMap
        (kernel: map (desktop: { inherit kernel desktop; }) desktops)
        kernels;
    in
    {
      nixosConfigurations = lib.listToAttrs (map
        (pt: { name = sysName pt; value = mkSystem pt; })
        matrix);

      # Build targets — one VM + one ISO per flavor:
      #   nix build .#vm | .#vm-gnome | .#vm-kde | .#vm-lab | .#vm-lab-gnome | .#vm-lab-kde
      #   nix build .#iso | .#iso-gnome | .#iso-kde | .#iso-lab | .#iso-lab-gnome | .#iso-lab-kde
      packages.${system} = lib.listToAttrs (
        (map
          (f: {
            name = pkgName "vm" f;
            value = self.nixosConfigurations.${sysName (f // { target = "system"; })}.config.system.build.vm;
          })
          flavors)
        ++
        (map
          (f: {
            name = pkgName "iso" f;
            value = self.nixosConfigurations.${sysName (f // { target = "iso"; })}.config.system.build.isoImage;
          })
          flavors)
      );
    };
}
