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

  outputs =
    { self, nixpkgs, luna-kernel, ... }:
    let
      system = "x86_64-linux";
      commonModules = [
        ./configuration.nix
        ./modules/luna.nix
      ];
      isoProfile = "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix";
    in
    {
      nixosConfigurations = {
        # Daily driver: stock nixpkgs kernel.
        luna-os = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules;
        };

        # Research track: our own 7.1.0-rc7 kernel (luna-os-kernel).
        luna-os-lab = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit luna-kernel; };
          modules = commonModules ++ [ ./modules/hermes-kernel.nix ];
        };

        # Installable live ISO (stock kernel — boots real hardware today).
        luna-os-iso = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            isoProfile
            ./modules/luna.nix
          ];
        };

        # Installable live ISO on our custom kernel. VM-only until the kernel
        # gains real-hardware drivers (see modules/hermes-kernel.nix).
        luna-os-lab-iso = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit luna-kernel; };
          modules = [
            isoProfile
            ./modules/luna.nix
            ./modules/hermes-kernel.nix
          ];
        };
      };

      # nix build .#vm | .#vm-lab | .#iso | .#iso-lab
      packages.${system} = {
        vm = self.nixosConfigurations.luna-os.config.system.build.vm;
        vm-lab = self.nixosConfigurations.luna-os-lab.config.system.build.vm;
        iso = self.nixosConfigurations.luna-os-iso.config.system.build.isoImage;
        iso-lab = self.nixosConfigurations.luna-os-lab-iso.config.system.build.isoImage;
      };
    };
}
