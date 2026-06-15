# luna-os

**Luna** — an AI agent (a fork of the [Hermes](https://github.com/NousResearch/hermes-agent)
agent, persona "Luna") woven into NixOS as **modules you add to any NixOS config**.
Drop her in and you get an always-on agent + a local dashboard, a `luna` CLI, and
a native **frosted-glass chat widget** in your panel — all declarative, all
rolled back instantly by NixOS generations.

> luna-os used to be a whole bespoke OS (a kernel × desktop × target matrix). It's
> now a **library**: the real product is the `nixosModules` you import. The custom
> kernel is an opt-in module; everything else runs on the stock kernel and works
> on any machine.

---

## Add Luna to your NixOS

```nix
{
  inputs.luna-os.url = "github:Penguinjanator/luna-os";
  outputs = { nixpkgs, luna-os, ... }: {
    nixosConfigurations.my-box = nixpkgs.lib.nixosSystem {
      modules = [
        luna-os.nixosModules.luna     # the whole stack: agent + dashboard + CLI
        luna-os.nixosModules.kde      # + her chat widget (KDE Plasma)
        ./hardware-configuration.nix
        # luna-os.nixosModules.lab-kernel   ← uncomment for the custom 7.1.0-rc7 kernel
      ];
    };
  };
}
```

`sudo nixos-rebuild switch --flake .#my-box`. Pull upstream Luna whenever you like
with `nix flake update luna-os` — **your** config (and anything Luna edits herself)
stays put.

### The modules

| Module | What it adds |
|---|---|
| `nixosModules.luna` (= `default`) | The core stack: the Hermes agent + dashboard services, the base userland, the `luna` CLI, Luna's identity. Stock kernel, runs anywhere. |
| `nixosModules.kde` / `.gnome` | A desktop session **+ Luna's chat widget + launchers** (pick one). |
| `nixosModules.lab-kernel` | **Optional** — our custom Linux 7.1.0-rc7 kernel: the future home of a `/dev/hermes` channel + an LSM cage. The one piece that carries a heavy build, so import it only if you want it. |

Each module closes over Luna's own inputs, so you import them with **no inputs or
specialArgs of your own** — just the lines above.

### A ready-made daily driver

[`examples/daily/`](examples/daily/) is a complete, tasteful desktop config — Luna
+ KDE + the everyday niceties (PipeWire, Bluetooth, fish + starship, Firefox,
fonts, common apps). Copy the folder, drop in your `hardware-configuration.nix`
(`nixos-generate-config`), rename the host, and rebuild.

---

## "Wait — how can a few files be a whole system?"

On a normal OS, the system *is* the millions of files on disk. On **NixOS, the
system is a *description*** — these `.nix` files — and a program called **Nix**
reads the description and *builds* the real OS from it.

> Think recipe vs. cooked meal. These files are the **recipe**; `nixos-rebuild`
> **cooks** them into the actual OS — the same way every time.

Two things fall out for free, and they're exactly why it's safe to let an *agent*
edit the system:

- **Reproducible** — the same files produce a bit-for-bit identical system;
  `flake.lock` pins everything.
- **Atomic & reversible** — every rebuild is a new *generation*. A bad change
  (yours or Luna's) → roll back instantly, even from the boot menu. Nothing is
  ever destructively overwritten.

---

## Talk to her

- **Panel widget** (KDE/GNOME): a frosted-glass chat with **tabs** — each tab is a
  conversation that **persists across reboots** — streaming replies, copy/paste,
  and a stop button. Click the crescent-moon icon in your bar.
- **`luna chat "…"`** / **`luna repl`** — stream her reply in a terminal;
  conversations thread, so she remembers (`luna chat --new` starts fresh).
- **`luna ask "…"`** — a zero-setup one-shot (no dashboard needed).
- **`luna status` / `luna sessions`** — what she's doing / recent conversations.

The dashboard that backs the widget + `luna chat` runs as a service automatically;
it mints its own per-machine auth token, so this all works on a fresh boot with
zero setup.

---

## Seeding Luna — her `.hermes` bundle

luna-os builds Luna's *brain* (the Hermes agent) into the system, but her
**identity and secrets** — profile, memory, API keys, channel logins — live in a
`.hermes` bundle you drop in **per machine**. It's a secret, so it's never baked
into an image or the store; until it's in place she has no API key and can't think.

It goes in **`/var/lib/hermes/.hermes`**. The agent provisions that directory as
`luna:users`, mode `2770`, and both the agent and the desktop run as `luna` — so
as the logged-in `luna` user you drop it straight in:

```sh
cp -a /path/to/your/.hermes/. /var/lib/hermes/.hermes/   # as luna, not root
sudo systemctl restart hermes-agent hermes-dashboard      # reload her profile
hermes -z "hola"                                          # a real answer = she's awake
```

If anything lands root-owned: `sudo chown -R luna:users /var/lib/hermes/.hermes`.

Other people bring their **own** keys (Hermes is model-agnostic) and import their
own personality — they never receive yours.

---

## Reference builds + live ISOs (optional)

luna-os also ships concrete reference systems and self-contained installer ISOs —
handy for a clean install or a quick VM look. All on the **stock** kernel:

```sh
nix build .#vm    # or .#vm-gnome / .#vm-kde   → ./result/bin/run-*-vm
nix build .#iso   # or .#iso-gnome / .#iso-kde → result/iso/*.iso
```

The desktop ISOs are **self-contained installers**: boot one (it autologins),
get online, and run `sudo luna-install` — it formats the target with
[`disko`](https://github.com/nix-community/disko) and installs the matching system
(`kde` ISO → `luna-os-kde`). It can also install **alongside an existing UEFI OS**
(dual-boot, option 2) without touching it. From then on you manage the box the
normal NixOS way — or, better, with a small local flake like `examples/daily/`
that imports the modules above, so **Luna can edit her own config and rebuild
herself**.

> Boot is `systemd-boot`, so the machine must be in **EFI mode**.

---

## The optional custom kernel

`nixosModules.lab-kernel` builds a Linux **7.1.0-rc7** kernel we own and control,
from source pinned in [`Penguinjanator/luna-os-kernel`](https://github.com/Penguinjanator/luna-os-kernel)
(only our `hermes-kernel.config` lives in this repo). It's the foundation for
in-kernel pieces an out-of-tree module can't provide — a `/dev/hermes` event/intent
channel and a Hermes **LSM** cage. It carries a real kernel build, which is exactly
why it's opt-in and off the default path.

---

## Where this is going

The OS is the *body*; Luna is the *brain*. The guiding principle holds: the
probabilistic LLM stays in **userspace**, outside the kernel's trust boundary.

The next frontier is **self-modification**: because the whole system is a
declarative description, Luna (running with full reach + sudo) can edit her own
local config and `nixos-rebuild` — reshaping her own OS, with generations as the
undo button. Safer and more total than kernel hacking ever was. The kernel-level
ideas (`/dev/hermes`, an LSM cage) live on as the opt-in `lab-kernel` for whoever
wants them.
