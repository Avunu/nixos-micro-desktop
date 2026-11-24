---
title: Install and run the micro desktop
description: "Who the nixos-micro-desktop flake suits, how to pick one of its three shells and a storage layout, how to install it, and how it keeps itself updated."
nav_title: Getting started
order: 1
tags: [desktop, install, updates]
updated: 2026-11-24
---

This document explains what `nixos-micro-desktop` is, who it is meant for, how to install it, how to choose between its desktop shells, and what it does to keep itself current. Read it before you put the flake on a laptop for yourself or someone close to you.

## What it is

`nixos-micro-desktop` is a NixOS flake that turns a blank disk into a lean Wayland desktop that maintains itself. You add one flake input and a short block of `microDesktop.*` options. The module supplies the disk layout, a tuned base system and a desktop shell of your choice.

It is a personal-use desktop, built for machines that Avunu and the people around it use every day: modest laptops, small disks, and people who would rather not think about Linux. It is not a business product.

> [!NOTE]
> There is no support promise behind it. The repository is MIT licensed, so you can read, copy and adapt it freely. Treat it as a well-documented starting point you adapt, not as something you deploy to customers.

It follows `nixos-unstable`, only builds for `x86_64-linux`, and runs without a firewall by default (see [Settings to review](#settings-to-review)). Those are fair trade-offs for a family laptop and poor ones for a business workstation.

## What you get

- Three interchangeable desktop shells on one shared base: niri with Noctalia, niri with DankMaterialShell (DMS), or GNOME.
- A disk layout declared with [disko](https://github.com/nix-community/disko): UEFI or legacy boot, an f2fs or btrfs root with zstd compression, and an optional swap partition that supports hibernation.
- Automatic maintenance: a daily flake update and rebuild, weekly garbage collection and store deduplication, and an hourly upgrade of each user's package profile.
- Software installation through GNOME Software, with no Nix knowledge needed.
- Responsiveness tuning for small machines: the latest kernel, `/tmp` on tmpfs, `systemd-oomd` policies that pick an app to kill before the compositor, a size-limited journal, and CPU, I/O and memory limits on the background rebuild.
- Shared desktop services: PipeWire, NetworkManager, Avahi, CUPS, GNOME keyring, XDG portals, fish and the Ghostty terminal.
- An input method (fcitx5) that gives you clipboard history on `Super+V` and an emoji picker on `Super+.`.

## Choose a desktop shell

Set `microDesktop.desktopShell` to one of three values. The apps, services and base system are identical across all of them. Only the compositor, the shell and the greeter change.

| `desktopShell` | Compositor | Shell | Greeter |
| --- | --- | --- | --- |
| `noctalia` (default) | niri | Noctalia | Noctalia greeter |
| `dms` | niri | DankMaterialShell | DMS greeter |
| `gnome` | Mutter | GNOME Shell | GDM |

### When to pick each one

- **`gnome`** is the safest choice for someone who has never used a tiling desktop. The module does not enable the full GNOME suite. It assembles the session from `gnome-session`, `gnome-shell` and GDM, so you get a slim desktop without the bundled apps, and the tray-icon extension is switched on system-wide.
- **`noctalia`** is the default and runs on niri, a scrolling tiling compositor. Pick it if you or your user want keyboard-driven window management with a polished shell. The module widens the shell's systemd restart limits, because it is also the session lock client and must never be allowed to give up restarting.
- **`dms`** is the other niri option. The module caps the DMS service at 4 GiB (`MemoryHigh`) and 8 GiB (`MemoryMax`) because of a lock-screen memory leak the module's author observed and noted in the source. If you choose DMS, expect the shell to restart itself under that cap rather than take the machine down.

> [!NOTE]
> The module description says all three shells share the same GNOME core apps (Nautilus, Loupe, Papers, Showtime and others). Changing shells does not change which apps you have.

### niri and NiriMod

On the niri shells the module also installs [NiriMod](https://github.com/srinivasr/nirimod), a visual editor for niri, and manages three files in the user's home directory:

| File | Who owns it |
| --- | --- |
| `~/.config/niri/config.kdl` | Nix. Rewritten on every activation. Do not edit it. |
| `~/.config/niri/nirimod.kdl` | You. Created empty if missing and never overwritten. |
| `~/.config/nirimod/settings.json` | Seeded once, then merged, so your preferences survive. The module forces `config_path` so NiriMod edits `nirimod.kdl` and not the Nix-owned file. |

Useful keys on the niri shells include `Super+T` for a terminal, `Super+Space` for the launcher, `Super+Q` to close a window and `Super+Shift+Slash` to show the hotkey overlay. `Super+Ctrl+R` runs `restart-shell`, which restarts the Noctalia or DMS user service.

## Choose a storage layout

disko declares the whole partition table, so the module expects to own the disk. Set these before you install.

| Option | Default | Notes |
| --- | --- | --- |
| `diskDevice` | `/dev/sda` | The install target. |
| `bootMode` | `uefi` | `uefi` uses systemd-boot on a 1 GiB ESP. `legacy` uses GRUB with a BIOS boot partition and a 1 GiB ext4 `/boot`. |
| `rootFilesystem` | `f2fs` | `f2fs` or `btrfs`. Decided at install time. |
| `compressionLevel` | `fast` | zstd level 1, 6 or 12 for `fast`, `balanced` and `max`. |
| `swapSizeGiB` | `8` | `0` leaves out the swap partition and hibernation. |

### f2fs or btrfs

The module's own advice is to choose `btrfs` on a new install. `f2fs` stays the default so existing machines keep working.

| | f2fs | btrfs |
| --- | --- | --- |
| Compression | `compress_algorithm=zstd:N` | `compress-force=zstd:N` |
| Freed space | Fewer bytes written, but `df` does not move | Returned to the filesystem |
| Trim | `nodiscard` plus a daily `fstrim` | `discard=async` |
| Layout | One flat root | `@`, `@home`, `@nix` and `@log` subvolumes |

> [!WARNING]
> `rootFilesystem` is an install-time decision. Changing it on an installed machine migrates and reformats nothing. The disk keeps the filesystem it was formatted with, so you reinstall to switch.

`compressionLevel` is safe to change later. New writes use the new level, and existing data stays as it is. Use `max` only for a machine with a small eMMC disk that downloads its packages from the binary cache, because level 12 compresses far more slowly than level 1.

### Swap and hibernation

zswap (lz4, with a pool of up to 20 percent of RAM) compresses pages in memory first, as described in [Swap Configuration](https://avunu.net/kb/linux/swap-configuration/). The swap partition is its overflow and the hibernation target. That is why it is a partition and not a swapfile. For hibernation, make the partition at least as large as RAM.

> [!WARNING]
> If a machine was installed before `swapSizeGiB` existed, set it to `0`. Otherwise the system looks for a swap partition that is not on the disk. The module bounds the wait at 15 seconds, so the machine still boots, but it boots 15 seconds slower and shows one failed unit in `systemctl --failed`.

## Install it

Boot the NixOS installer and do not partition anything, because disko formats the disk. Then use one of the routes below.

### The installer menu

The flake exposes `configure`, `install` and `deploy` apps, plus installer ISOs, built with [nixos-install-helper](https://github.com/Avunu/nixos-install-helper). The installer builds its questionnaire from the `microDesktop.*` options, so the shell, filesystem and disk questions appear automatically. List what the flake offers with:

```bash
nix flake show github:Avunu/nixos-micro-desktop
```

Run the wizard straight from GitHub with:

```bash
nix run github:Avunu/nixos-micro-desktop
```

The wizard lets you choose between three deployment paths, described in the installer's documentation:

- **Unattended ISO:** the settings are baked in at build time and the ISO installs offline.
- **Guided ISO:** a generic ISO that asks for identity, disk and network details on the machine itself.
- **Network install:** `nixos-anywhere` installs to a reachable target over SSH.

For a local install, the installer seeds `/etc/nixos` with a small flake that pulls this module from GitHub and applies your answers from `/etc/nixos/microDesktop-settings.json`.

### Manual install from the sample flake

The repository includes a sample consumer flake in `local/flake.nix`. Fetch it, edit it and rebuild:

```bash
sudo curl -o /etc/nixos/flake.nix \
  https://raw.githubusercontent.com/Avunu/nixos-micro-desktop/main/local/flake.nix
sudo nano /etc/nixos/flake.nix
sudo rm /etc/nixos/configuration.nix
sudo nixos-rebuild switch --flake /etc/nixos#<HOSTNAME> --accept-flake-config
sudo reboot
```

Edit `hostName`, `username`, `diskDevice`, `bootMode`, `rootFilesystem` and the other values in the file before you rebuild. The sample sets `hostName` and `username` as variables at the top and contains an example machine name, so replace both.

`--accept-flake-config` lets Nix use the project's binary cache. Without it you get a warning and a local build.

> [!NOTE]
> A rebuild does not repartition a disk. The manual route therefore suits a machine that already runs NixOS, and the installer suits a blank disk. We have not run the manual route end to end for this document.

### Remote install with nixos-anywhere

Edit `local/flake.nix`, then run the script from inside the `local/` directory:

```bash
./install.sh <IP_ADDRESS>
```

The script copies your flake to `/etc/nixos` on the target and runs `nixos-anywhere` as `root` against it, so the machine can rebuild itself afterwards.

## Settings to review

Everything lives under `microDesktop.*`. The defaults below are the ones to check before you hand a machine to someone.

| Option | Default | Notes |
| --- | --- | --- |
| `hostName`, `username` | `nixos`, `user` | Set your own. |
| `initialPassword` | `password` | Change it after first login. |
| `timeZone`, `locale` | `America/New_York`, `en_US.UTF-8` | Set your own. |
| `stateVersion` | `25.11` | Leave it unless you know why you are changing it. |
| `enableSsh` | `false` | Off by default. |
| `sshPasswordAuth`, `sshRootLogin` | `true`, `"yes"` | Tighten both if you enable SSH. |
| `enableVpn` | `false` | Adds NetworkManager's OpenVPN, vpnc, OpenConnect and L2TP plugins. |
| `extraPackages` | `[ ]` | System packages for this one machine. |

Four more options, `enableAppImage`, `enableFileIndexing`, `enableFingerprint` and `enableScanning`, are off by default. Each one adds roughly 220 to 400 MB to the system, which is why they are hidden from the installer wizard. Turn on only what the machine needs.

> [!WARNING]
> The module sets `networking.firewall.enable` to `false` as a default. It also opens the Miracast sink ports (7236 and 7250) and mDNS, but those rules do nothing while the firewall is off. If the laptop leaves your home network, set `networking.firewall.enable = true` in the flake. The module uses `mkDefault`, so a plain assignment overrides it.

Anything the options do not cover is ordinary NixOS. The module sets its defaults with `mkDefault`, so a normal assignment in your flake wins.

## Install software

Software goes in through GNOME Software. Its PackageKit backend, [nix-profile-packagekit-backend](https://github.com/Avunu/nix-profile-packagekit-backend), installs packages from nixpkgs into the user's own profile at `~/.nix-profile`, with no root access. The backend maps an install to `nix profile install nixpkgs#<package>`, so the person using the laptop never has to touch Nix.

For something every user of the machine needs, add it to `extraPackages` in the flake.

> [!NOTE]
> Flatpak is not set up by this module. The software center installs from nixpkgs, and AppImage support is off by default because it brings in a 222 MB locale archive.

## How updates work

Three timers keep the machine current, and each is throttled so it does not disturb whoever is using the laptop.

| What | When | What it does |
| --- | --- | --- |
| `system-upgrade` | Daily, and at boot if a run was missed | Runs `nix flake update` in `/etc/nixos`, then `nixos-rebuild switch` only if `flake.lock` changed. |
| `nix-profile-upgrade` (user timer) | Hourly | Runs `nix profile upgrade --all` for that user. |
| Garbage collection and store optimization | Weekly | Deletes generations older than 7 days and deduplicates the store. |

### Guards on the rebuild

The `system-upgrade` service skips a run, and tries again the next day, when:

- the connection is metered, or
- less than 25 percent of RAM is available.

When it does run, it runs at the lowest CPU priority (`Nice=19`), with reduced CPU and I/O weights, a memory ceiling of 25 percent of RAM and read and write caps of 100 MB/s on `/nix/store`. The compositor gets the opposite treatment: a higher CPU and I/O share, and protection from the out-of-memory killer.

To run an upgrade yourself, start the unit or call the command it installs:

```bash
sudo systemctl start system-upgrade
```

`profile-upgrade` is a second command on the path. It runs `nix profile upgrade --all --impure` for the current user.

### The binary cache

Rebuilding daily from `nixos-unstable` would mean a lot of local compiling. The project's CI builds the installed system from its own lock file and pushes only what `cache.nixos.org` cannot serve to `nixos-micro-desktop.cachix.org`. That covers a patched fcitx5, a trimmed copy of `linux-firmware` and the system derivations themselves. Dependabot bumps the lock daily, and each bump merges once CI is green.

A machine only gets cache hits when its nixpkgs revision is one CI has built. Otherwise it builds those few paths itself, which takes longer but still works.

### Going back

On UEFI installs, systemd-boot keeps the 10 most recent system generations (`configurationLimit`). The boot menu timeout is 2 seconds in either boot mode, so an update that breaks the desktop can be undone from the boot menu. The weekly cleanup deletes generations older than 7 days, so do not count on rolling back further than that.

## Limits to know about

- It tracks `nixos-unstable`, so a daily update can bring a regression. There is no staging or testing step on your machine.
- Hardware tuning is aimed at Intel laptops. Examples are `thermald`, `i915` kernel parameters and BFQ on SATA and eMMC. Other hardware may need per-device kernel parameters in your flake.
- The default `initialPassword` is `password`, and the firewall is off. Change both for any machine you hand to someone else.
- Some default values, such as memory limits and build concurrency, were chosen against the author's own machines. Check them against the hardware in front of you.
- Noctalia comes from nixpkgs, and a comment in the module notes that the packaged version tracked a v5 beta when it was written. Expect some change.
- Issues and pull requests are welcome on [GitHub](https://github.com/Avunu/nixos-micro-desktop). `nix develop` gives you a development shell with `update-flake` and `mcp-nixos`.

## Related documents

- [Building a Web Kiosk USB with web_kiosk](https://docs.avunu.net/web-kiosk/docs/getting-started/), for a single-purpose NixOS appliance that runs from a USB drive.
- [Mounting Cloud Storage with nixos-rclone](https://docs.avunu.net/nixos-rclone/docs/mounts-and-sync/), for mounting or syncing cloud storage on a NixOS desktop.
- [Why Nix for Business Systems](https://avunu.net/kb/nixos/why-nix-for-business-systems/), for the business case behind the same tooling.
