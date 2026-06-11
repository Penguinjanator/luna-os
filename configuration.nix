# Base system for luna-os. Minimal, headless, serial-console NixOS that boots
# in QEMU. This is the "walk" stage: stock kernel, clean boot, autologin shell.
# The custom linuxManualConfig kernel gets layered in afterwards.
{ lib, pkgs, ... }:
{
  networking.hostName = "luna-os";

  # Serial console so the QEMU VM works headless.
  boot.kernelParams = [
    "console=ttyS0,115200"
    "console=tty1"
  ];

  # Dev login: autologin on the console so we land straight in a shell. The
  # `luna` user itself is defined in modules/luna.nix (shared by every variant,
  # including the live ISOs), so it isn't redefined here.
  services.getty.autologinUser = "luna";

  users.users.root.initialPassword = "root"; # dev convenience only

  # The shared base userland (editors, git, net/disk tools, …) lives in
  # modules/luna.nix so every variant — including the ISOs — gets it. Add only
  # VM-specific extras here if ever needed.

  # QEMU VM resources. These go under `vmVariant` because the qemu-vm options
  # (memorySize/cores/graphics) are only in scope for the VM sub-evaluation
  # that builds system.build.vm, not the base system. graphics = false =>
  # the console comes out our serial line.
  virtualisation.vmVariant.virtualisation = {
    memorySize = 2048;
    cores = 4;
    graphics = false;
  };

  # Pins stateful-data defaults to a release. Don't change casually.
  system.stateVersion = "24.11";
}
