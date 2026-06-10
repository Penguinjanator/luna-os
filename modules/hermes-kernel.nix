# hermes-kernel.nix — luna-os-lab's custom kernel (the "run" track).
#
# Packages OUR Linux 7.1.0-rc7 source (Penguinjanator/luna-os-kernel, pinned via
# the `luna-kernel` flake input) + our .config through nixpkgs' linuxManualConfig,
# and makes it the system kernel. This is the foundation for in-tree pieces
# (the /dev/hermes channel, a custom LSM) that out-of-tree modules can't provide.
#
# The source comes from the flake input (private repo, our key); only our
# ~144 KB .config lives in this repo. Future kernel patches go in ./patches/.
{ lib, pkgs, luna-kernel, ... }:
let
  hermesKernel = pkgs.linuxManualConfig {
    version = "7.1.0-rc7";
    src = luna-kernel; # our kernel source, pinned by the flake
    configfile = ./hermes-kernel.config;
    allowImportFromDerivation = true;
  };
in
{
  boot.kernelPackages = pkgs.linuxPackagesFor hermesKernel;

  # Firmware blobs for Wi-Fi / GPUs (iwlwifi, amdgpu, …) that our drivers need.
  hardware.enableRedistributableFirmware = true;

  # ZFS is an out-of-tree module that doesn't support bleeding-edge / -rc
  # kernels — zfs-kernel refuses to build against 7.1.0-rc7. The installer ISO
  # pulls ZFS in by default, so disable it for anything on our custom kernel.
  boot.supportedFilesystems.zfs = lib.mkForce false;

  # hermes-kernel.config now ships broad hardware support — NVMe, Wi-Fi,
  # AMD/Nvidia/Intel GPU, common filesystems, the virtio drivers the VM needs,
  # AND every module in NixOS's default initrd set (SATA/USB glue + HID quirk
  # drivers + device-mapper). So NixOS includes its default modules normally —
  # nothing is forced empty, and keyboards / mice / quirky peripherals all work.
}
