# luna-install — self-contained luna-os installer.
#
# This is the BODY of a writeShellScriptBin (installer.nix adds the bash
# shebang), kept as a real file so the array/brace-heavy bash doesn't collide
# with Nix's ${} interpolation inside an '' string. `@TARGET@` is replaced at
# build time with the system config matching this ISO (e.g. luna-os-kde).
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "luna-install must run as root:  sudo luna-install" >&2
  exit 1
fi

flake=/etc/luna-os
target="@TARGET@"

echo
echo "  luna-install — installs luna-os ($target)"
echo "  ==========================================="
echo

# ── Discover target drives ─────────────────────────────────────────────────
# Whole disks only (no partitions / ROM / loop). For each: size, model, and
# whether it already carries filesystems — i.e. probably holds an OS or data we
# would destroy. A drive can hold a filesystem with zero partitions, so the
# "has data" test is "any filesystem present", not "has partitions".
mapfile -t disks < <(lsblk -dn -o NAME,TYPE | awk '$2 == "disk" { print $1 }')
if [ "${#disks[@]}" -eq 0 ]; then
  echo "  No drives found (lsblk listed no disks). Aborting." >&2
  exit 1
fi

devs=()
lines=()
empty=()
default=-1
for n in "${disks[@]}"; do
  dev="/dev/$n"
  size=$(lsblk -dn -o SIZE "$dev" 2>/dev/null | tr -d ' ')
  model=$(lsblk -dn -o MODEL "$dev" 2>/dev/null | sed -e 's/[[:space:]]*$//')
  [ -n "$model" ] || model="(no model)"
  nfs=$(lsblk -nro FSTYPE "$dev" 2>/dev/null | grep -c . || true)
  nparts=$(lsblk -n -o NAME "$dev" 2>/dev/null | tail -n +2 | grep -c . || true)
  if [ "$nfs" -gt 0 ]; then
    state="$nparts partition(s), $nfs filesystem(s) -- HAS DATA/OS"
    is_empty=0
  elif [ "$nparts" -gt 0 ]; then
    state="$nparts partition(s), no filesystems"
    is_empty=1
  else
    state="empty -- no partitions"
    is_empty=1
  fi
  devs+=("$dev")
  empty+=("$is_empty")
  lines+=("$dev   $size   $model   [$state]")
  if [ "$is_empty" -eq 1 ] && [ "$default" -lt 0 ]; then
    default=$(( ${#devs[@]} - 1 ))
  fi
done
[ "$default" -ge 0 ] || default=0   # none empty -> default to the first drive

# ── Menu (empty drives marked *, offered as the default) ───────────────────
echo "  Drives found ( * = empty, recommended ):"
echo
for i in "${!devs[@]}"; do
  mark="   "
  [ "${empty[$i]}" -eq 1 ] && mark=" * "
  printf "  %s%2d) %s\n" "$mark" "$(( i + 1 ))" "${lines[$i]}"
done
echo

read -rp "  Install onto which drive? [number, default $(( default + 1 ))]: " pick
pick="${pick:-$(( default + 1 ))}"
case "$pick" in
  '' | *[!0-9]*) echo "  Not a number. Aborting." >&2; exit 1 ;;
esac
idx=$(( pick - 1 ))
if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#devs[@]}" ]; then
  echo "  No drive #$pick in the list. Aborting." >&2
  exit 1
fi
disk="${devs[$idx]}"

# ── Confirm (extra warning when the drive already holds data) ──────────────
echo
echo "  Selected:  $disk"
lsblk "$disk" || true
echo
if [ "${empty[$idx]}" -ne 1 ]; then
  echo "  !! WARNING: $disk already has partitions/filesystems."
  echo "  !! Installing here ERASES EVERYTHING on it (any existing OS/data)."
  echo
fi
read -rp "  Type YES to WIPE $disk and install luna-os ($target): " confirm
if [ "$confirm" != "YES" ]; then
  echo "  Aborted -- nothing changed."
  exit 1
fi

# ── Partition + format the chosen drive with disko ─────────────────────────
# disko.nix is a function { disk ? "/dev/sda", ... }; feed it the chosen drive
# via a tiny wrapper so we don't depend on a particular disko --arg syntax.
echo
echo ">>> Partitioning + formatting $disk with disko ..."
work=$(mktemp -d)
printf 'import %s/disko.nix { disk = "%s"; }\n' "$flake" "$disk" > "$work/disko.nix"
disko --mode disko "$work/disko.nix"
rm -rf "$work"

# ── Install ────────────────────────────────────────────────────────────────
echo
echo ">>> Installing luna-os ($target) -- this builds/fetches the system ..."
nixos-install --flake "$flake#$target" --no-root-passwd

# ── Carry the deploy key into the installed system (keyed ISOs only) ────────
# A keyed ISO has the git+ssh key at /root/.ssh; copy it onto the new disk as a
# plain 0600 root file so the box can self-update with no manual key drop.
key=/root/.ssh/luna-os_ed25519
if [ -f "$key" ]; then
  install -d -m 700 /mnt/root/.ssh
  install -m 600 "$key" /mnt/root/.ssh/luna-os_ed25519
  echo ">>> deploy key copied into the installed system (/root/.ssh)"
fi

echo
echo "  Done. Next:"
echo "    1. Power off and remove the ISO from the VM."
echo "    2. Boot from $disk; log in as luna (password: luna)."
echo "    3. Drop her .hermes bundle into /var/lib/hermes/.hermes."
