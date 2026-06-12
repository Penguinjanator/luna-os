# luna-os

An AI-native operating system built on **NixOS** — the eventual home of the
**Hermes** agent. From one small set of files it builds a whole **matrix** of
variants along three axes:

- **kernel** — `stock` (the NixOS kernel, boots anywhere) or `lab` (**our own
  custom Linux 7.1.0-rc7 kernel**, where kernel-level AI work — `/dev/hermes`,
  eBPF, a security module — will live).
- **desktop** — `gnome`, `kde`, or `terminal`-only. This is the "flavor", done
  exactly how upstream NixOS ships its installers: one image per desktop.
- **target** — an installable/VM `system`, or a live `.iso`.

The terminal points keep their original names — **`luna-os`** (stock daily driver)
and **`luna-os-lab`** (research track) — and desktops add a `-gnome` / `-kde` infix.

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
    ├── luna.nix               # The "luna" identity. Imports the agent + dev
    │                          # toolchains, ships the base userland, drops an
    │                          # /etc/luna-os/release marker. Shared by EVERY variant.
    ├── dev.nix                # General-purpose dev languages (Rust, Python, C/C++,
    │                          # Go, Node/TypeScript) baked into every variant.
    ├── hermes-agent.nix       # The Hermes agent daemon as a systemd service.
    │                          # Skeleton for now (disabled); the LLM brain lives
    │                          # in USERSPACE by design, never in the kernel.
    ├── hermes-kernel.nix      # Builds our CUSTOM kernel (the lab track) from our
    │                          # source + config, and makes it the system kernel.
    ├── hermes-kernel.config   # The Linux kernel .config for our custom kernel.
    └── desktops/              # The desktop "flavors" — one layer each.
        ├── gnome.nix          # GNOME (GDM + GNOME).
        └── kde.nix            # KDE Plasma 6 (SDDM + Plasma).
```

A NixOS system is assembled by importing **modules** (the `.nix` files above) into
a **configuration**. Every variant shares `modules/luna.nix`; the flake just layers
on a kernel module (for `lab`) and a desktop module (for `gnome`/`kde`). The whole
matrix is generated from a single `mkSystem` function in `flake.nix` — no
duplication, which is why so few files cover so many variants.

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

Want a desktop instead of a shell? Swap in a flavor: `nix build .#vm-gnome`
(or `.#vm-kde`, `.#vm-lab-gnome`, …) opens a graphical QEMU window.

> No KVM (e.g. inside WSL2)? It falls back to slower software emulation
> automatically — it still works, just give it a minute to boot.

---

## Build an installable ISO

```sh
# Stock-kernel ISO — boots and installs on real hardware:
nix build .#iso          # or .#iso-gnome / .#iso-kde for a live desktop
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

> **Note:** the `.#iso-lab*` images (on our custom kernel) boot to a working login
> in a **VM** today. Broad real-hardware coverage (enterprise RAID/HBA controllers,
> some Wi-Fi/GPU firmware paths) is still being filled in — see the roadmap. Use the
> stock `.#iso*` images for real hardware today.

---

## Installing to disk (and why it won't clobber your config)

Booting the ISO is great for a look, but it's a **live image** — its writable
layer is RAM-backed, so it forgets everything (logins, Luna's memory, anything
you change) on reboot. For real use you **install** luna-os onto a disk. The
question everyone asks first:

> **Won't installing overwrite all our config?** No — and the recipe metaphor is
> exactly why. This repo is the **recipe**; installing just **cooks it onto a
> disk**. The flake stays the one source of truth, so you can't overwrite it by
> building from it. The installed system *is* luna-os — provided you install
> **from this flake**, not the stock NixOS installer.

### You don't run `nixos-generate-config`

A normal NixOS install begins with `nixos-generate-config`, which writes two
files. Here they have different fates:

- **`configuration.nix`** (the starter template) — **skip it, always.** It's for
  people who don't already have a config. The flake replaces it outright.
- **`hardware-configuration.nix`** (auto-detected disk + initrd modules) — this
  holds the one genuinely machine-specific thing: *which partition is `/`* and
  *what's needed to mount it*. We declare that in the flake with
  [`disko`](https://github.com/nix-community/disko) instead of generating it — so
  the disk layout is reproducible and there is **no hand-edited hardware file and
  no `nixos-generate-config` step at all.**

### The flow

1. Boot the live ISO (`.#iso-kde`, …).
2. `disko` partitions + formats the target disk straight from the flake.
3. `nixos-install --flake <luna-os>#luna-os-kde` builds the system from this repo
   and writes it onto the disk.
4. Reboot into a **persistent** luna-os.
5. Drop in Luna's `.hermes` bundle (her keys + memory — the per-machine secret
   that deliberately lives *outside* the flake).

From then on you change the system the usual way — edit the flake, then
`nixos-rebuild switch --flake <luna-os>#luna-os-kde`. Every rebuild is a new
generation you can roll back to; nothing is ever destructively overwritten.

> **Status:** today's `luna-os-*` configs are live-image / VM shaped and don't
> yet declare a disk. Adding the `disko` layout + a bootloader (`systemd-boot`)
> as an installable variant is the one remaining piece — purely additive, and on
> the roadmap.

---

## Build targets at a glance

The grid is **kernel × desktop**, with a `vm-` and an `iso-` build for each cell:

| Desktop | Stock kernel — VM / ISO | Lab kernel (7.1.0-rc7) — VM / ISO |
|---|---|---|
| terminal | `.#vm` / `.#iso` | `.#vm-lab` / `.#iso-lab` |
| GNOME | `.#vm-gnome` / `.#iso-gnome` | `.#vm-lab-gnome` / `.#iso-lab-gnome` |
| KDE Plasma 6 | `.#vm-kde` / `.#iso-kde` | `.#vm-lab-kde` / `.#iso-lab-kde` |

- **`vm-*`** builds a `run-*-vm` script — terminal VMs are headless/serial; desktop
  VMs open a graphical QEMU window.
- **`iso-*`** builds a hybrid live ISO at `result/iso/*.iso` — boot the desktop ones
  and you land straight in a live GNOME/KDE session.
- Every variant ships the shared base userland **and** the dev languages
  (Rust, Python, C/C++, Go, Node/TypeScript).

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
