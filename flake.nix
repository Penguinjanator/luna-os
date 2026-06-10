{
  description = "luna-os: an AI-native NixOS, home to the Hermes agent";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
    in
    {
      # The OS itself. Build/boot a VM with:
      #   nix build .#nixosConfigurations.luna-os.config.system.build.vm
      #   ./result/bin/run-luna-os-vm
      nixosConfigurations.luna-os = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix
          ./modules/luna.nix
        ];
      };

      # Convenience alias: `nix build .#vm`
      packages.${system}.vm =
        self.nixosConfigurations.luna-os.config.system.build.vm;
    };
}
