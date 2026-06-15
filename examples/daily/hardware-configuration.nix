# hardware-configuration.nix — PLACEHOLDER. Replace this ENTIRE file with the one
# NixOS generates for YOUR machine:
#
#     sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
#
# The stub below exists only so the template evaluates as-is; it will NOT boot
# real hardware. Disk device paths, filesystem types, and the initrd kernel
# modules are machine-specific — that's exactly what nixos-generate-config detects.
{ ... }:
{
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "ahci" "usbhid" "sd_mod" ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };
  swapDevices = [ ];
}
