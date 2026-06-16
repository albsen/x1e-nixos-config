#!/usr/bin/env bash

set -euo pipefail

root=/mnt
run_install=1

usage() {
    cat <<'EOF'
Usage: install-t14s-oled-el2-kernel.sh [--root /mnt] [--no-install]

Patch an already generated NixOS target configuration so the installed system
uses the X1E ThinkPad T14s OLED EL2 kernel, DTBs, firmware and boot files.

Run this from the live ISO after the graphical installer has completed, with
the installed root mounted at /mnt and the installed ESP mounted at /mnt/boot.

Options:
  --root PATH    Mounted target root. Defaults to /mnt.
  --no-install  Only update configuration files; do not rerun nixos-install.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --root)
            if [ "$#" -lt 2 ]; then
                printf 'error: --root requires a path\n' >&2
                exit 2
            fi
            root="$2"
            shift 2
            ;;
        --no-install)
            run_install=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'error: unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
target_nixos="$root/etc/nixos"
configuration="$target_nixos/configuration.nix"
module="$target_nixos/x1e-t14s-oled-el2.nix"
target_repo="$target_nixos/x1e-nixos-config"

if [ "$(id -u)" -ne 0 ]; then
    printf 'error: run this script as root\n' >&2
    exit 1
fi

if [ ! -d "$root" ]; then
    printf 'error: target root does not exist: %s\n' "$root" >&2
    exit 1
fi

if [ ! -f "$configuration" ]; then
    printf 'error: missing %s\n' "$configuration" >&2
    printf 'mount the installed root at %s first\n' "$root" >&2
    exit 1
fi

if [ ! -d "$root/boot" ]; then
    printf 'error: missing %s/boot\n' "$root" >&2
    printf 'mount the installed EFI system partition at %s/boot first\n' "$root" >&2
    exit 1
fi

printf 'Copying x1e-nixos-config into %s\n' "$target_repo"
rm -rf "$target_repo"
mkdir -p "$target_repo"
rsync -aL \
    --exclude '.git' \
    --exclude 'result' \
    --exclude 'result-*' \
    "$repo_root"/ "$target_repo"/
chmod -R u+w "$target_repo"

cat > "$module" <<'EOF'
{ pkgs, ... }:

{
  imports = [
    ./x1e-nixos-config/modules/common.nix
    (import ./x1e-nixos-config/default.nix).nixosModules.x1e
  ];

  hardware.lenovo-thinkpad-t14s-oled.enable = true;
  x1e.el2.enable = true;

  nixpkgs.config.allowUnfreePredicate = pkg:
    pkgs.lib.getName pkg == "tcblaunch.exe";
}
EOF

if ! grep -Fq './x1e-t14s-oled-el2.nix' "$configuration"; then
    backup="$configuration.before-x1e-t14s-oled-el2"
    cp "$configuration" "$backup"

    tmp="$(mktemp)"
    awk '
      {
        print
        if ($0 ~ /\.\/hardware-configuration\.nix/ && inserted == 0) {
          print "      ./x1e-t14s-oled-el2.nix"
          inserted = 1
        }
      }
      END {
        if (inserted == 0) {
          exit 42
        }
      }
    ' "$configuration" > "$tmp" || {
        status="$?"
        rm -f "$tmp"
        if [ "$status" -eq 42 ]; then
            printf 'error: could not find ./hardware-configuration.nix import in %s\n' "$configuration" >&2
            printf 'add ./x1e-t14s-oled-el2.nix to the imports list manually\n' >&2
        fi
        exit "$status"
    }

    cp "$tmp" "$configuration"
    rm -f "$tmp"
    printf 'Updated %s; backup is %s\n' "$configuration" "$backup"
else
    printf '%s already imports ./x1e-t14s-oled-el2.nix\n' "$configuration"
fi

if [ "$run_install" -eq 1 ]; then
    printf 'Running nixos-install for %s\n' "$root"
    nixos-install --root "$root" --no-root-passwd --no-channel-copy
else
    printf 'Skipped nixos-install because --no-install was passed\n'
fi
