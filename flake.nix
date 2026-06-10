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
      };

      # Convenience: `nix build .#vm`  /  `nix build .#vm-lab`
      packages.${system} = {
        vm = self.nixosConfigurations.luna-os.config.system.build.vm;
        vm-lab = self.nixosConfigurations.luna-os-lab.config.system.build.vm;
      };
    };
}
