# NixOS Micro Desktop

A modular NixOS configuration for modern, lean, self-maintaining Wayland desktops. One flake input and a short block of `microDesktop.*` options give you a disk layout, a tuned base system and your choice of desktop shell. The system then keeps itself current.

What you get

-   **Three interchangeable shells** on one shared base: niri with Noctalia, niri with DankMaterialShell, or GNOME. [Details](#desktop-shells)
-   **Declarative disks** via [disko](https://github.com/nix-community/disko): UEFI or legacy boot, f2fs or btrfs root with zstd, a swap partition for hibernation with zswap in front of it. [Details](#storage)
-   **Self-updating.** A daily `nix flake update` and rebuild runs only when the lock changed and is throttled so it doesn't disturb the session. Weekly GC and store optimisation run alongside it, and the nix profile upgrades hourly. A [CI-fed binary cache](#updates-and-binary-cache) keeps most of this to downloads.
-   **Software through GNOME Software.** Its PackageKit backend installs to the user's nix profile, so nobody has to touch Nix to add an app.
-   **Tuned for responsiveness on modest hardware:**
    -   Latest kernel, tmpfs `/tmp`, `transparent_hugepage=madvise`, BFQ on SATA/eMMC.
    -   `systemd-oomd` with per-slice policy, so a runaway app is chosen before the compositor.
    -   `thermald` and `power-profiles-daemon`.
    -   Bounded journald, and CPU/IO/memory limits on the background rebuild.
    -   Trimmed `linux-firmware` and locale archive to keep the closure small.
-   **Shared desktop services:** PipeWire, NetworkManager (VPN plugins opt-in), Avahi, CUPS with browsed, Miracast sink, GNOME keyring and online accounts, XDG portals, nix-ld, fish and Ghostty.
-   **Input method:** fcitx5 clipboard history (`Super+V`) and emoji picker (`Super+.`), with a patched 20-row clipboard page and a Material theme.
-   **Unattended or guided install** through [nixos-install-helper](https://github.com/Avunu/nixos-install-helper). The installer menu is generated from the `microDesktop.*` options, so new options show up in it automatically.

## Desktop shells

Set `microDesktop.desktopShell`. All three share the same base system, apps and services. Only the shell, compositor and greeter change.

| desktopShell | Compositor | Shell | Greeter |
| --- | --- | --- | --- |
| noctalia (default) | niri | Noctalia | Noctalia greeter |
| dms | niri | DankMaterialShell | DMS greeter |
| gnome | Mutter | GNOME Shell | GDM |

`gnome` does not use `services.desktopManager.gnome.enable`. That would add the full GNOME app suite and force ibus, which conflicts with the fcitx5 pickers. The session is assembled from `gnome-session`, `gnome-shell` and GDM instead.

### niri and NiriMod

On the niri shells, [NiriMod](https://github.com/srinivasr/nirimod) (a visual niri editor) is installed and provisioned on every activation:

-   `~/.config/niri/config.kdl` is Nix-owned and rewritten each time. It includes `/etc/niri/config.kdl`, then `nirimod.kdl`, then the shell's generated files.
-   `~/.config/niri/nirimod.kdl` is yours. It is created empty if missing and never overwritten.
-   `~/.config/nirimod/settings.json` is seeded once, then merged, so your preferences survive. Only `config_path` is forced, so NiriMod never edits the Nix-owned file.

## Storage

disko declares the whole partition table, so the module expects to own the disk. Set these before installing:

| Option | Default | Notes |
| --- | --- | --- |
| diskDevice | /dev/sda | Install target |
| bootMode | uefi | uefi: systemd-boot on an ESP. legacy: GRUB, BIOS boot partition and ext4 /boot |
| rootFilesystem | f2fs | f2fs or btrfs. Install-time only, nothing is migrated |
| compressionLevel | fast | zstd 1 / 6 / 12 (fast / balanced / max). Safe to change later |
| swapSizeGiB | 8 | 0 omits the partition and hibernation |

**f2fs or btrfs.** f2fs is the default for compatibility with existing installs. btrfs is the better choice for a new install:

|  | f2fs | btrfs |
| --- | --- | --- |
| Compression | compress_algorithm=zstd:N | compress-force=zstd:N |
| Freed space | Fewer bytes written, df doesn't move | Returned to the filesystem |
| Trim | nodiscard and a daily fstrim | discard=async |
| Layout | One flat root | @, @home, @nix, @log subvolumes |

**Swap.** zswap (lz4, 20% RAM pool) compresses pages in memory first. The swap partition is its overflow and the hibernation target, which is why it's a partition rather than a swapfile.

**Machines installed before `swapSizeGiB` existed** must set it to `0`. A nonzero value points at a partition that isn't on the disk. `storage.nix` bounds the resulting wait (`resumeflags=x-systemd.device-timeout=15s`, `nofail`), so the machine boots 15 s slower with one failed unit instead of hanging. Both settings are load-bearing, so read the comments in [modules/system/storage.nix](modules/system/storage.nix) before touching them.

## Installation

Boot the NixOS installer and **don't partition anything**, because disko formats the disk. Then use either route.

**Installer helper.** The flake exposes `apps` (configure, install, deploy) and ISOs from nixos-install-helper, with a menu derived from `microDesktop.*`:

```sh
nix flake show github:Avunu/nixos-micro-desktop
```

**Manual, from the sample flake:**

```sh
sudo curl -o /etc/nixos/flake.nix \
  https://raw.githubusercontent.com/Avunu/nixos-micro-desktop/main/local/flake.nix
sudo nano /etc/nixos/flake.nix        # hostName, username, diskDevice, bootMode, rootFilesystem, …
sudo rm /etc/nixos/configuration.nix
sudo nixos-rebuild switch --flake /etc/nixos#<hostName> --accept-flake-config
sudo reboot
```

`--accept-flake-config` lets Nix use the project's binary cache. Without it you get a warning and a local build.

**Remote, with nixos-anywhere:** edit [local/flake.nix](local/flake.nix), then run `./install.sh <ip>` from inside `local/`.

## Options

Everything is under `microDesktop.*`. See [modules/options.nix](modules/options.nix) for full descriptions.

| Option | Default |  |
| --- | --- | --- |
| desktopShell | noctalia | noctalia, dms or gnome |
| hostName, username, initialPassword | nixos, user, password | Change the password after first login |
| timeZone, locale, stateVersion | America/New_York, en_US.UTF-8, 25.11 |  |
| diskDevice, bootMode, rootFilesystem, compressionLevel, swapSizeGiB |  | See Storage |
| enableSsh, sshPasswordAuth, sshRootLogin | false, true, "yes" | Tighten these if you enable SSH |
| enableVpn | false | NetworkManager OpenVPN, vpnc, OpenConnect and L2TP plugins |
| extraPackages | [ ] | System packages for this machine |
| enableAppImage, enableFileIndexing, enableFingerprint, enableScanning | false | Closure trims, hidden from the installer wizard (about 220–400 MB each) |

Anything else is plain NixOS. The module sets its defaults with `mkDefault`, so ordinary assignments in your flake override them.

## Updates and binary cache

Installed machines run `system-upgrade` daily. It updates `/etc/nixos/flake.lock`, rebuilds only if the lock changed, and skips when memory is tight. It runs at low CPU/IO priority, and `nix-daemon` has memory, CPU and IO guards of its own.

CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)) builds the `install` system from this repo's lock and pushes only what cache.nixos.org can't serve to [nixos-micro-desktop.cachix.org](https://nixos-micro-desktop.cachix.org). That covers the patched fcitx5, the trimmed firmware and the system derivations. Dependabot bumps the lock daily, and [dependabot-auto-merge.yml](.github/workflows/dependabot-auto-merge.yml) merges each bump once `ci` is green.

A machine only gets cache hits when its nixpkgs revision is one CI has built. Otherwise it builds those few paths locally.

Maintainer setup the workflows rely on:

-   Add `CACHIX_AUTH_TOKEN` under both Actions secrets and Dependabot secrets.
-   Enable **Allow auto-merge** in the repository settings.
-   Add a ruleset on `main` that requires the `ci` check.

## Repository layout

```
flake.nix            inputs, installer wiring, nixosModules.microDesktop
local/               sample consumer flake and nixos-anywhere script
modules/options.nix  the microDesktop.* option surface
modules/system/      boot, hardware, memory, network, nix, storage, users
modules/desktop/     common, input-method, niri, noctalia, dms, gnome
configs/             niri KDL, GTK/Qt settings, fcitx5 theme and patch
```

## Contributing

Issues and pull requests are welcome on [GitHub](https://github.com/Avunu/nixos-micro-desktop). `nix develop` (or direnv) gives you a dev shell with `update-flake` and `mcp-nixos`.
