# disko.nix — STANDALONE disk layout for the `disko` formatter.
#
# This is NOT a NixOS module and is intentionally NOT imported by flake.nix. It's
# consumed by the disko CLI to partition + format + mount the target disk during
# a disk install (README "Route B"):
#
#   sudo nix --experimental-features 'nix-command flakes' \
#     run github:nix-community/disko/latest -- --mode disko ./disko.nix
#
# The installed system mounts by LABEL (NIXROOT / NIXBOOT) via modules/disk.nix,
# so this layout stamps those labels on. That keeps the two install routes in
# sync: whether disko formats the disk or you do it by hand with the same labels,
# the system finds its root either way.
#
# Single disk, GPT, UEFI: a 512 MB EFI System partition + an ext4 root.
# `device = /dev/sda` is VirtualBox's default SATA disk. For NVMe use
# /dev/nvme0n1; for a virtio disk (plain QEMU) use /dev/vda.
{
  disko.devices.disk.main = {
    device = "/dev/sda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
            extraArgs = [ "-n" "NIXBOOT" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            extraArgs = [ "-L" "NIXROOT" ];
          };
        };
      };
    };
  };
}
