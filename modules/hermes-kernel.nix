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

  # Our kernel builds every VM-critical driver straight in (=y): virtio
  # (pci/mmio/blk/net/scsi), 9p, virtiofs, ext4, overlay, ahci, sd, tpm, loop…
  # So the initrd needs NO loadable modules. Rather than chase each module NixOS
  # lists in availableKernelModules (virtio_rng, hid_apple, tpm-*…) — many of
  # which our lean kernel doesn't ship — drop the default set and force the
  # available-modules list empty. The VM boots entirely from built-ins.
  # NOTE: NixOS-module change, not a kernel .config change — no recompile.
  boot.initrd.includeDefaultModules = false;
  boot.initrd.availableKernelModules = lib.mkForce [ ];
  # qemu-vm also force-loads virtio_gpu / virtio_rng via initrd.kernelModules;
  # we're headless and don't ship those. Empty this too — built-ins cover boot.
  boot.initrd.kernelModules = lib.mkForce [ ];
}
