{
  description = "luna-os: an AI-native NixOS, home to the Hermes agent";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Our kernel source = Penguinjanator/luna-os-kernel (private).
    # For local dev we pin the working copy via git+file (fast, no fetch).
    # Switch to git+ssh://git@github.com/Penguinjanator/luna-os-kernel for
    # off-machine / CI builds (uses the luna-os key, works with private repos).
    luna-kernel = {
      url = "git+file:///home/potato/work-code/linux-master";
      flake = false;
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
    { self, nixpkgs, luna-kernel, ... }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;

      isoProfile = "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix";

      # ---- the three axes of the matrix ----
      kernels = [ "stock" "lab" ];
      desktops = [ "terminal" "gnome" "kde" ];
      targets = [ "system" "iso" ];

      # Desktop layers; "terminal" adds nothing.
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
          user = "nixos";
        };
      };

      # Build one nixosSystem for a {kernel, desktop, target} point in the matrix.
      mkSystem = { kernel, desktop, target }:
        lib.nixosSystem {
          inherit system;
          # Only the lab kernel module needs the kernel source as a specialArg.
          specialArgs = lib.optionalAttrs (kernel == "lab") { inherit luna-kernel; };
          modules =
            # A "system" is the installable/VM base; an "iso" is the live image.
            (if target == "iso" then [ isoProfile ] else [ ./configuration.nix ])
            ++ [ ./modules/luna.nix ]
            ++ kernelLayer.${kernel}
            ++ desktopLayer.${desktop}
            ++ lib.optional (target == "iso" && desktop != "terminal") isoDesktopAutologin
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
