# luna-install — self-contained luna-os installer.
#
# Body of a writeShellScriptBin (installer.nix adds the bash shebang); kept as a
# real file so the array/brace-heavy bash doesn't collide with Nix's ${}
# interpolation inside an '' string. @TARGET@ is replaced at build time with the
# system config matching this ISO (e.g. luna-os-kde).
#
# Two install modes, sharing finish_install (nixos-install + key copy + done):
#   1) erase a whole drive  -> install_whole_drive  (disko)
#   2) dual-boot alongside an existing OS -> install_dualboot
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "luna-install must run as root:  sudo luna-install" >&2
  exit 1
fi

flake=/etc/luna-os
target="@TARGET@"
ESP_PARTTYPE="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"   # GPT type GUID: EFI System

CHOSEN_DISK=""
CHOSEN_DISK_EMPTY=0

# ── Pick a whole drive ──────────────────────────────────────────────────────
# Sets CHOSEN_DISK (/dev/NAME) + CHOSEN_DISK_EMPTY. $1 = "prefer-empty" to flag
# empty drives and default to one (whole-drive mode), or "any" (dual-boot: you
# pick the drive your other OS lives on, so there's no empty preference).
pick_target_disk() {
  local prefer="$1" n dev size model nfs nparts i pick idx default=-1 mark
  local disks=() devs=() lines=() empt=()
  mapfile -t disks < <(lsblk -dn -o NAME,TYPE | awk '$2 == "disk" { print $1 }')
  if [ "${#disks[@]}" -eq 0 ]; then
    echo "  No drives found. Aborting." >&2
    exit 1
  fi
  for n in "${disks[@]}"; do
    dev="/dev/$n"
    size=$(lsblk -dn -o SIZE "$dev" 2>/dev/null | tr -d ' ')
    model=$(lsblk -dn -o MODEL "$dev" 2>/dev/null | sed -e 's/[[:space:]]*$//')
    [ -n "$model" ] || model="(no model)"
    nfs=$(lsblk -nro FSTYPE "$dev" 2>/dev/null | grep -c . || true)
    nparts=$(lsblk -n -o NAME "$dev" 2>/dev/null | tail -n +2 | grep -c . || true)
    if [ "$nfs" -gt 0 ]; then
      lines+=("$dev   $size   $model   [$nparts part, $nfs fs -- HAS DATA/OS]"); empt+=(0)
    elif [ "$nparts" -gt 0 ]; then
      lines+=("$dev   $size   $model   [$nparts part, no filesystems]"); empt+=(1)
    else
      lines+=("$dev   $size   $model   [empty -- no partitions]"); empt+=(1)
    fi
    devs+=("$dev")
    if [ "$prefer" = "prefer-empty" ] && [ "${empt[-1]}" -eq 1 ] && [ "$default" -lt 0 ]; then
      default=$(( ${#devs[@]} - 1 ))
    fi
  done
  [ "$default" -ge 0 ] || default=0

  echo
  if [ "$prefer" = "prefer-empty" ]; then
    echo "  Drives ( * = empty, recommended ):"
  else
    echo "  Drives (pick the one holding your other OS):"
  fi
  echo
  for i in "${!devs[@]}"; do
    mark="   "
    if [ "$prefer" = "prefer-empty" ] && [ "${empt[$i]}" -eq 1 ]; then mark=" * "; fi
    printf "  %s%2d) %s\n" "$mark" "$(( i + 1 ))" "${lines[$i]}"
  done
  echo
  read -rp "  Which drive? [number, default $(( default + 1 ))]: " pick
  pick="${pick:-$(( default + 1 ))}"
  case "$pick" in '' | *[!0-9]*) echo "  Not a number. Aborting." >&2; exit 1 ;; esac
  idx=$(( pick - 1 ))
  if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#devs[@]}" ]; then
    echo "  No drive #$pick. Aborting." >&2
    exit 1
  fi
  CHOSEN_DISK="${devs[$idx]}"
  CHOSEN_DISK_EMPTY="${empt[$idx]}"
}

# ── Shared tail: install the system + carry the deploy key ──────────────────
# Expects the new root mounted at /mnt (and ESP at /mnt/boot). $1 = boot hint.
finish_install() {
  local boot_disk="$1" key=/root/.ssh/luna-os_ed25519
  echo
  echo ">>> Installing luna-os ($target) -- this builds/fetches the system ..."
  nixos-install --flake "$flake#$target" --no-root-passwd

  # Keyed ISOs carry the git+ssh deploy key; copy it onto the new system so it
  # can self-update without a manual key drop (plain 0600 root file, not store).
  if [ -f "$key" ]; then
    install -d -m 700 /mnt/root/.ssh
    install -m 600 "$key" /mnt/root/.ssh/luna-os_ed25519
    echo ">>> deploy key copied into the installed system (/root/.ssh)"
  fi

  echo
  echo "  Done. Next:"
  echo "    1. Power off and remove the ISO."
  echo "    2. Boot from $boot_disk; choose luna-os in the menu; log in as luna (password: luna)."
  echo "    3. Drop her .hermes bundle into /var/lib/hermes/.hermes."
}

# ── Mode 1: erase a whole drive ─────────────────────────────────────────────
install_whole_drive() {
  local disk confirm work
  pick_target_disk prefer-empty
  disk="$CHOSEN_DISK"

  echo
  echo "  Selected:  $disk"
  lsblk "$disk" || true
  echo
  if [ "$CHOSEN_DISK_EMPTY" -ne 1 ]; then
    echo "  !! WARNING: $disk already has partitions/filesystems."
    echo "  !! Erasing the WHOLE drive destroys everything on it."
    echo
  fi
  read -rp "  Type YES to WIPE the whole drive $disk and install luna-os ($target): " confirm
  if [ "$confirm" != "YES" ]; then echo "  Aborted -- nothing changed."; exit 1; fi

  echo
  echo ">>> Partitioning + formatting $disk with disko ..."
  # disko.nix is a function { disk ? "/dev/sda", ... }; feed it the chosen drive
  # via a tiny wrapper so we don't depend on a particular disko --arg syntax.
  work=$(mktemp -d)
  printf 'import %s/disko.nix { disk = "%s"; }\n' "$flake" "$disk" > "$work/disko.nix"
  disko --mode disko "$work/disko.nix"
  rm -rf "$work"

  finish_install "$disk"
}

# ── Mode 2: install alongside an existing OS (dual-boot) ────────────────────
install_dualboot() {
  local disk esp="" confirm i pick pidx root
  local pnames=() pdevs=() plines=() pok=()
  local pname pdev psize pfst ptype

  echo
  echo "  Dual-boot installs luna-os onto an EMPTY partition you have already"
  echo "  made, sharing the disk's existing EFI partition. It does NOT touch any"
  echo "  other partition. If you haven't yet: shrink your other OS and leave an"
  echo "  empty partition FIRST, from within that OS, then come back."
  pick_target_disk any
  disk="$CHOSEN_DISK"

  mapfile -t pnames < <(lsblk -nro NAME "$disk" 2>/dev/null | tail -n +2)
  if [ "${#pnames[@]}" -eq 0 ]; then
    echo "  $disk has no partitions -- nothing to dual-boot with. Aborting." >&2
    exit 1
  fi

  for pname in "${pnames[@]}"; do
    pdev="/dev/$pname"
    psize=$(lsblk -dn -o SIZE "$pdev" 2>/dev/null | tr -d ' ')
    pfst=$(lsblk -dn -o FSTYPE "$pdev" 2>/dev/null | tr -d ' ')
    ptype=$(lsblk -dn -o PARTTYPE "$pdev" 2>/dev/null | tr 'A-Z' 'a-z' | tr -d ' ')
    pdevs+=("$pdev")
    if [ "$ptype" = "$ESP_PARTTYPE" ]; then
      [ -n "$esp" ] || esp="$pdev"
      plines+=("$pdev   $psize   [EFI System -- shared boot, not selectable]"); pok+=(0)
    elif [ -n "$pfst" ]; then
      plines+=("$pdev   $psize   $pfst   [HAS DATA -- would be ERASED]"); pok+=(2)
    else
      plines+=("$pdev   $psize   [empty -- recommended for root]"); pok+=(1)
    fi
  done

  if [ -z "$esp" ]; then
    echo "  No EFI System Partition on $disk -- its OS isn't UEFI, or there's no" >&2
    echo "  ESP. Clean dual-boot needs the other OS to be UEFI. Aborting." >&2
    exit 1
  fi

  echo
  echo "  EFI partition (shared boot): $esp"
  echo
  echo "  Partitions on $disk -- pick an EMPTY one for luna-os root:"
  echo
  for i in "${!pdevs[@]}"; do
    printf "  %2d) %s\n" "$(( i + 1 ))" "${plines[$i]}"
  done
  echo
  read -rp "  luna-os root onto which partition? [number]: " pick
  case "$pick" in '' | *[!0-9]*) echo "  Not a number. Aborting." >&2; exit 1 ;; esac
  pidx=$(( pick - 1 ))
  if [ "$pidx" -lt 0 ] || [ "$pidx" -ge "${#pdevs[@]}" ]; then
    echo "  No partition #$pick. Aborting." >&2
    exit 1
  fi
  root="${pdevs[$pidx]}"
  if [ "${pok[$pidx]}" -eq 0 ]; then
    echo "  $root is the EFI partition -- it can't be luna-os root. Aborting." >&2
    exit 1
  fi

  echo
  echo "  Plan:"
  echo "    - format  $root  as ext4, label NIXROOT   (luna-os root)"
  echo "    - relabel $esp  FAT label -> NIXBOOT       (shared EFI; files kept)"
  echo "    - install luna-os ($target); the boot menu will list luna-os + your other OS"
  echo "    - every OTHER partition is left untouched"
  echo
  if [ "${pok[$pidx]}" -eq 2 ]; then
    echo "  !! WARNING: $root has a filesystem -- formatting it ERASES its data."
    echo
  fi
  read -rp "  Type YES to format $root and install: " confirm
  if [ "$confirm" != "YES" ]; then echo "  Aborted -- nothing changed."; exit 1; fi

  echo
  echo ">>> Formatting $root as ext4 (label NIXROOT) ..."
  mkfs.ext4 -F -L NIXROOT "$root"
  echo ">>> Relabeling EFI partition $esp -> NIXBOOT (label only, non-destructive) ..."
  fatlabel "$esp" NIXBOOT
  udevadm settle || true

  echo ">>> Mounting NIXROOT -> /mnt, NIXBOOT -> /mnt/boot ..."
  mount /dev/disk/by-label/NIXROOT /mnt
  mkdir -p /mnt/boot
  mount /dev/disk/by-label/NIXBOOT /mnt/boot

  finish_install "$disk"
}

# ── Main ────────────────────────────────────────────────────────────────────
echo
echo "  luna-install — installs luna-os ($target)"
echo "  ==========================================="
echo
echo "  How do you want to install?"
echo
echo "    1) Erase an entire drive (dedicate it to luna-os)"
echo "    2) Install alongside an existing OS on the same drive (dual-boot)"
echo
read -rp "  Choose [1/2]: " mode
case "$mode" in
  1) install_whole_drive ;;
  2) install_dualboot ;;
  *) echo "  Please choose 1 or 2. Aborting."; exit 1 ;;
esac
