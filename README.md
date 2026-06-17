# NixOS configs for Snapdragon X Elite based devices

This repo targets the T14S 64GB RAM OLED snapdragon XElite laptop.

Based on https://github.com/kuruczgy/x1e-nixos-config

Add tcblaunch.exe by placing it in the root of this repo and running.

```console
./scripts/add-tcblaunch.sh
```

To keep a local encrypted backup outside Git, create a password-protected
archive:

```console
./scripts/create-vendor-archive.sh
```

Restore it later with:

```console
./scripts/restore-vendor-dependencies.sh
./scripts/add-tcblaunch.sh
```

Building the iso:

```console
nix build '.#lenovo-thinkpad-t14s-iso' '.#slbounce' '.#qebspil'
```

Remote install over SSH:

The ISO includes an SSH server for remote installs with tools such as
`nixos-anywhere`. Add public keys to this file on the USB stick:

```text
ssh/authorized_keys
```

At boot, the live system imports that file into `/root/.ssh/authorized_keys`.
SSH password login is disabled; only keys from the USB file are accepted.

Terminal-only boot:

To boot a GRUB entry without the graphical environment, highlight the entry,
press `e`, append this to the `linux` line, then boot with `Ctrl+x` or `F10`:

```text
systemd.unit=multi-user.target
```

If the display manager still starts, use this stronger one-time override:

```text
systemd.unit=multi-user.target systemd.mask=display-manager.service
```

## Other projects with support for Snapdragon X Elite devices

- [Ubuntu Concept](https://discourse.ubuntu.com/t/ubuntu-24-10-concept-snapdragon-x-elite/48800): Supports many X Elite based laptops
- [Cadmium](https://github.com/Maccraft123/Cadmium): Also for the Yoga Slim 7x
- [Ubuntu for the Snapdragon Dev Kit](https://github.com/jglathe/linux_ms_dev_kit/wiki/Bringing-up-the-SnapDragon-Dev-Kit-for-Windows-with-Linux-%E2%80%90-*with*-working-display)
- Surface Pro 11: [Arch Linux ARM](https://github.com/dwhinham/linux-surface-pro-11) and [NixOS](https://github.com/andre4ik3/nixos-surface-pro-11)

