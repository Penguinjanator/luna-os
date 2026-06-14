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
    │                          # /etc/luna-os-release marker. Shared by EVERY variant.
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
  *what's needed to mount it*. You give the flake that information **either** by
  formatting with the labels it expects (manual) **or** by declaring the whole
  layout with [`disko`](https://github.com/nix-community/disko) (automated) —
  **either way there's no hand-edited hardware file and no `nixos-generate-config`
  step at all.**

### The easy way — `luna-install`

The live ISO is a **self-contained installer**: the flake is baked in at
`/etc/luna-os`, `disko` is on `PATH`, and a one-shot `luna-install` does the lot.
The whole install:

1. In VirtualBox: **Settings → System → Motherboard → ✅ Enable EFI**.
2. Boot the `kde` ISO (it autologins as `luna`); get online, and make sure Luna's
   **deploy key** is in place — see *The deploy key* below (or bake it into the ISO).
3. Run it:
   ```sh
   sudo luna-install
   ```
   It shows the target disk, waits for you to type `YES`, then formats with
   `disko` and installs the system that **matches the ISO you booted** (`kde` →
   `luna-os-kde`, `kde-lab` → `luna-os-lab-kde`, …).
4. Power off, remove the ISO, boot from the disk, drop in `.hermes`.

No `git clone`, no flake URLs to remember. The two manual routes below are exactly
what `luna-install` automates — reach for them only if you want to drive it by hand.

### The two other ways

Both **skip `nixos-generate-config`** — they differ only in *who* prepares the disk.

**Route A — manual** (mirrors the official NixOS guide, with our flake at the end):

1) Boot the ISO and get it online.

2) Partitioning

To partition the persistent storage run `sudo fdisk /dev/diskX`, where \`diskX\` is the disk you want to partition. Typically, this might be something like `/dev/sda`.

Depending on your hardware, you should follow either the DOS or (U)EFI partitioning instructions.

A very simple example setup is given here.

**DOS Instructions**

In the DOS interactive prompt, enter the following commands:

- `o` (dos disk label)
- `n` new
- `p` primary (4 primary in total)
- `1` (partition number \[1/4\])
- `2048` first sector (alignment for performance)
- `+500M` last sector (boot sector size)
- rm signature (`Y`), if ex. => warning of overwriting existing system, could use wipefs
- `n`
- `p`
- `2`
- default (fill up partition)
- default (fill up partition)
- `w` (write)

**UEFI Instructions**

In the UEFI interactive prompt, enter the following commands:

- `g` (gpt disk label)
- `n`
- `1` (partition number \[1/128\])
- `2048` first sector
- `+500M` last sector (boot sector size)
- `t`
- `1` (EFI System)
- `n`
- `2`
- default (fill up partition)
- default (fill up partition)
- `w` (write)

3. Format **with the labels the flake expects**, so no hardware file is needed:
   ```sh
   mkfs.fat -F 32 /dev/sda1 && fatlabel /dev/sda1 NIXBOOT
   mkfs.ext4 -L NIXROOT /dev/sda2
   ```
4. Mount:
   ```sh
   mount /dev/disk/by-label/NIXROOT /mnt
   mkdir -p /mnt/boot && mount /dev/disk/by-label/NIXBOOT /mnt/boot
   ```
5. Install **from the flake** — this one step replaces both `nixos-generate-config`
   and the hand-edited config:
   ```sh
   nixos-install --flake github:Penguinjanator/luna-os#luna-os-kde
   ```
6. Reboot, `passwd` your user, drop in Luna's `.hermes`.

**Route B — disko** (semi-automated): `disko` reads the layout in `./disko.nix`
and partitions + formats + mounts the disk for you — no hand-partitioning:

1. Boot the ISO; get online, then grab the repo (for `disko.nix`):
   `git clone https://github.com/Penguinjanator/luna-os && cd luna-os`
2. Format the disk from the layout — **this wipes the target disk**:
   ```sh
   sudo nix --experimental-features 'nix-command flakes' \
     run github:nix-community/disko/latest -- --mode disko ./disko.nix
   ```
3. `sudo nixos-install --flake .#luna-os-kde`
4. Reboot, `passwd`, drop in `.hermes`.

Either way, from then on you change the system the usual NixOS way — edit the flake,
then `nixos-rebuild switch --flake …#luna-os-kde`. Every rebuild is a new generation
you can roll back to; nothing is ever destructively overwritten.

> **EFI required:** boot is `systemd-boot`, so the machine must be in **EFI mode**.
> In VirtualBox, tick **Settings → System → Motherboard → Enable EFI** before you
> install.
>
> **Status — done:** the `system`-target configs (`luna-os`, `luna-os-kde`, …) now
> declare the disk by label (`modules/disk.nix`) + `systemd-boot`, and `./disko.nix`
> holds the disko layout, so both routes work today. The target disk is `/dev/sda`
> (VirtualBox's SATA default) — change it in `disko.nix` for NVMe (`/dev/nvme0n1`)
> or virtio (`/dev/vda`).

### The deploy key — letting the installer fetch Luna's private inputs

Every install route ends in `nixos-install --flake …`, which **re-evaluates the
flake on the live machine** and fetches luna-os's private inputs — `hermes` (needed
by *every* variant) and, on the `lab` images, the custom kernel — over `git+ssh`.
The ISO bakes in the `github-penguin` SSH **alias** (`modules/luna.nix`) but **not
the key**: a private key is a secret, dropped per-machine, never committed or
shipped. Without it the install dies the moment it reaches `hermes`, with
`Permission denied (publickey)`.

Two ways to get the key onto the live system:

**Manual (per boot)** — in the live session, *before* `sudo luna-install`:

```sh
sudo install -d -m700 /root/.ssh
sudo tee /root/.ssh/luna-os_ed25519 >/dev/null <<'EOF'
<paste the full contents of your luna-os_ed25519 private key>
EOF
sudo chmod 600 /root/.ssh/luna-os_ed25519
sudo ssh-keyscan github.com 2>/dev/null | sudo tee /root/.ssh/known_hosts >/dev/null
sudo ssh -T git@github-penguin   # expect "Hi Penguinjanator! …" — it exits 1, that's normal
```

It goes in **root's** `.ssh` because `luna-install` runs as root — so test it with
`sudo ssh -T`, not a bare `ssh` (a normal user can't read a root-owned `600` key,
which looks exactly like "the key's right there but it won't authenticate").

**Baked in (`LUNA_BAKE_KEY`)** — for repeat testing, bake the key into the image at
*build* time so a freshly-booted ISO runs `luna-install` with zero setup. It's
**opt-in**: the key is only included when you set the env var **and** build
`--impure`, so a normal `nix build .#iso-kde` stays pure and keyless.

```sh
LUNA_BAKE_KEY=$HOME/.ssh/luna-os_ed25519 nix build --impure .#iso-kde
```

An activation script (`modules/dev-ssh-key.nix`, gated in `flake.nix`) then installs
the key to `/root/.ssh/luna-os_ed25519` (mode `600`) on first boot.

> **Security — local testing only.** A baked key lands in the image's
> **world-readable** nix store; the `600` on `/root/.ssh` is cosmetic, since anyone
> who can read the ISO can `cat` the key straight out of `/nix/store`. Never
> distribute or back up a keyed ISO, and rotate the key if one ever leaks. Build
> real images **without** the env var (keyless), and hand the key over per-machine.

### Dual-boot (same disk, alongside another OS)

`luna-install` can put luna-os next to an existing **UEFI** OS (e.g. Windows) on
the same disk — sharing one EFI partition and one boot menu — without touching
the other OS.

**Prepare first, from your other OS:** shrink it and leave an **empty partition**
for luna-os (Windows: *Disk Management → Shrink Volume*, then make a partition in
the freed space — or leave it unallocated and create one with a live GParted).
luna-install never resizes or repartitions; it only formats the empty partition
you point it at.

Then boot the ISO and choose dual-boot:
```sh
sudo luna-install      # option 2) Install alongside an existing OS
```
Pick the disk, then the **empty partition** for luna-os root. luna-install
formats just that partition (`NIXROOT`), relabels the existing EFI partition to
`NIXBOOT` (the FAT label only — the other OS's boot files are untouched), and
installs. `systemd-boot` then lists **luna-os and your other OS** at startup.

> Requires the other OS to be **UEFI** (so there's an EFI System Partition to
> share). Legacy BIOS/MBR installs can't dual-boot this way.

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

---

## Seeding Luna — her `.hermes` bundle

luna-os builds Luna's *brain* (the Hermes agent) into the OS, but her **identity
and secrets** — profile, memory, API keys, channel logins — live in a `.hermes`
bundle you drop in **per machine**. It's a secret, so it's never baked into the
image or the store; until it's in place she has no API key and can't think. This
is the `drop in .hermes` step the install routes above refer to.

It goes in **`/var/lib/hermes/.hermes`**. The agent service provisions that
directory as `luna:users`, mode `2770`, and both the agent and the desktop run as
`luna` — so as the logged-in `luna` user you drop it straight in:

```sh
# copy your bundle's CONTENTS into the provisioned dir (as luna, not root):
cp -a /path/to/your/.hermes/. /var/lib/hermes/.hermes/
ls -la /var/lib/hermes/.hermes               # should read luna:users
sudo systemctl restart hermes-agent          # reload her profile
# (find the unit name if unsure: systemctl --type=service | grep hermes)
```

If anything lands root-owned, `sudo chown -R luna:users /var/lib/hermes/.hermes`
fixes it. Then `hermes -z "hola"` should get a real answer — that's how you know
she's awake.
