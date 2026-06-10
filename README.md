# luna-os

An AI-native operating system built on **NixOS** — the eventual home of the
**Hermes** agent. It ships in two flavors from one small set of files:

- **`luna-os`** — daily-driver track, on the stock NixOS kernel (boots anywhere).
- **`luna-os-lab`** — research track, on **our own custom Linux 7.1.0-rc7 kernel**,
  where kernel-level AI work (`/dev/hermes`, eBPF, a security module) will live.

---

## "Wait — how can a handful of files be a whole OS?"

This is the part that surprises everyone, so it's worth saying up front.

On a normal OS, the system *is* the millions of files installed on the disk.
On **NixOS, the system is a *description*** — and these `.nix` files are that
description. A program called **Nix** reads the description and *builds* the
actual operating system from it: the Linux kernel, the init system, every
service, every user, the firewall, the lot.

> Think of it like a recipe vs. a cooked meal. This repo is the **recipe**
> (a few kilobytes). When you run `nix build`, Nix **cooks** it into the real,
> multi-gigabyte, bootable OS — the same way every time, on any machine.

Two consequences fall out of this for free:

- **Reproducible** — the same files produce a bit-for-bit identical OS. `flake.lock`
  pins the exact versions of everything so it never drifts.
- **Atomic & reversible** — every rebuild is a new "generation". If a change breaks
  something, you roll back to the previous generation instantly (even from the boot
  menu). Nothing is ever destructively overwritten.

That's why so few files can be a complete OS, and why it's safe to experiment.

---

## What each file does

```
luna-os/
├── flake.nix                  # The entry point. Declares INPUTS (nixpkgs, our
│                              # kernel source) and OUTPUTS (the OS variants +
│                              # build targets like .#vm and .#iso).
├── flake.lock                 # Auto-generated lockfile pinning exact versions.
├── configuration.nix          # The base system: the `luna` user, hostname,
│                              # installed packages, VM tuning.
└── modules/
    ├── luna.nix               # The "luna" identity. Imports the agent module and
    │                          # drops an /etc/luna-os/release marker. This is where
    │                          # future pieces (desktop, policy) get wired in.
    ├── hermes-agent.nix       # The Hermes agent daemon as a systemd service.
    │                          # Skeleton for now (disabled); the LLM brain lives
    │                          # in USERSPACE by design, never in the kernel.
    ├── hermes-kernel.nix      # Builds our CUSTOM kernel (the lab track) from our
    │                          # source + config, and makes it the system kernel.
    └── hermes-kernel.config   # The Linux kernel .config for our custom kernel.
```

A NixOS system is assembled by importing **modules** (the `.nix` files above) into
a **configuration**. `luna-os` and `luna-os-lab` share the same modules and differ
by exactly **one import** — the custom kernel. That's the whole trick.

---

## Prerequisites

1. **Nix with flakes enabled.** Easiest install (Linux/WSL/macOS):
   ```sh
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```
   (The Determinate installer turns on flakes for you. After installing, open a
   fresh shell so `nix` is on your `PATH`.)
2. **QEMU**, to run the VMs / boot the ISOs locally:
   ```sh
   sudo apt install qemu-system-x86      # Debian/Ubuntu
   ```

---

## Run it in a VM (fastest way to see it)

```sh
# Stock-kernel daily driver:
nix build .#vm
./result/bin/run-luna-os-vm

# Our custom 7.1.0-rc7 kernel (compiles the kernel the first time — slow):
nix build .#vm-lab
./result/bin/run-luna-os-vm
```

The VM auto-logs in as user `luna`. Confirm which kernel you're on with
`uname -r` (`6.18.x` = stock, `7.1.0-rc7` = ours). **Quit QEMU** with
`Ctrl-a` then `x`.

> No KVM (e.g. inside WSL2)? It falls back to slower software emulation
> automatically — it still works, just give it a minute to boot.

---

## Build an installable ISO

```sh
# Stock-kernel ISO — boots and installs on real hardware:
nix build .#iso
ls result/iso/*.iso
```

Then either boot it in QEMU:
```sh
qemu-system-x86_64 -m 2048 -cdrom result/iso/*.iso
```
…or write it to a USB stick (this ERASES the stick — pick the right device!):
```sh
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

NixOS produces a **hybrid ISO** (boots both UEFI and legacy BIOS) containing the
kernel, an initrd, a squashfs of the whole system, a bootloader, and a live
installer — all generated from this repo. No manual bootloader/initramfs wrangling.

> **Note:** `.#iso-lab` (the ISO on our custom kernel) currently boots **only in a
> VM**. Our kernel is tuned lean for QEMU and doesn't yet carry real-hardware
> drivers (NVMe, Wi-Fi, AMD/Nvidia GPUs, …). Making it boot real machines is an
> in-progress goal — see the roadmap. Use `.#iso` for real hardware today.

---

## Build targets at a glance

| Command | What you get |
|---|---|
| `nix build .#vm` | QEMU VM, stock kernel |
| `nix build .#vm-lab` | QEMU VM, our custom 7.1.0-rc7 kernel |
| `nix build .#iso` | Installable live ISO, stock kernel (real hardware) |
| `nix build .#iso-lab` | Installable live ISO, custom kernel (VM-only for now) |

---

## The custom kernel

The lab track runs a Linux kernel **we own and control**. Its source lives in a
separate private repo, **`Penguinjanator/luna-os-kernel`**, and is pinned into
this flake via the `luna-kernel` input in `flake.nix`. Only our ~144 KB
`hermes-kernel.config` lives here; Nix fetches the source and compiles it
reproducibly.

We keep a local working copy of that kernel repo (e.g. `../linux-master`). To
pull fixes from mainline Linux into it, run its `setup-remotes.sh` once, then
`git fetch upstream` and `git cherry-pick <commit>`.

---

## Where this is going

luna-os exists to weave an LLM agent (**Hermes**) into the OS itself. The OS is the
*body*; Hermes is the *brain*. Planned, roughly in order:

1. **`hermesd`** — flesh out the userspace agent daemon.
2. **`/dev/hermes`** — a kernel event/intent channel (now possible because we
   control the kernel).
3. **eBPF reflexes + a Hermes LSM** — fast in-kernel reactions and a deterministic
   permission cage around the agent.

The guiding principle: the probabilistic LLM stays in **userspace**, outside the
kernel's trust boundary, and acts only through mediated, sandboxed interfaces.
