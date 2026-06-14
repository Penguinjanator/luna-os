# disk.nix — filesystems + bootloader for an INSTALLED luna-os.
#
# Layered onto the `system` target only (the live ISOs bring their own squashfs
# root + boot). Root and ESP are referenced by LABEL, so the system boots no
# matter how the disk was prepared:
#   - disko:   nix run github:nix-community/disko -- --mode disko ./disko.nix
#   - by hand: mkfs.ext4 -L NIXROOT  +  mkfs.fat -n NIXBOOT   (README "Route A")
# then `nixos-install --flake .#luna-os-kde`.
#
# Boot: EFI + systemd-boot (the VM/firmware must be EFI — in VirtualBox tick
# Settings -> System -> Motherboard -> Enable EFI).
{ ... }:
{
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXROOT";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NIXBOOT";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Show the boot menu for a few seconds: needed to pick luna-os vs another OS in
  # a dual-boot (systemd-boot auto-detects Windows/other EFI entries), and gives
  # single-boot users the generation/rollback menu too.
  boot.loader.timeout = 5;

  # initrd drivers needed to reach the root disk early: VirtualBox AHCI/SATA +
  # USB, and virtio for plain QEMU. (The lab kernel already carries these; the
  # stock kernel's defaults cover them too — listing them is belt-and-suspenders.)
  boot.initrd.availableKernelModules = [
    "ahci"
    "ata_piix"
    "sd_mod"
    "sr_mod"
    "uas"
    "usbhid"
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
  ];
}
