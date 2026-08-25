NixOS Micro Desktop

NixOS Micro Desktop is an OpenSUSE Aeon-inspired desktop, but powered by NixOS. The goal is to create a NixOS configuration that's suitable for "family and friends".

If you really care about declarative systems, you probably want to use Nix directly to install and configure your computer. Micro Desktop, in contrast, provides the goodness of a minimal but functional system that can be provisioned using GNOME software, without tinkering with the underlying system.

## Features

-   Latest kernel for optimal hardware support
-   Three interchangeable desktop shells — see below
-   GNOME core apps and services shared across all of them
-   Network Manager with VPN support
-   Flatpak integration for easy application management
-   Optimized audio setup with PipeWire
-   Printer and scanner support out of the box
-   Choice of f2fs or BTRFS root, with zstd compression either way
-   Automatic system maintenance (TRIM, garbage collection)
-   Enhanced XDG portal integration for better desktop experience
-   And much more!

## Desktop shells

Set `microDesktop.desktopShell` in your local flake. All three share the same base system — kernel and filesystem tuning, GNOME core apps and services, PipeWire, printing and scanning, portals, and the fcitx5 clipboard-history (`Super+V`) and emoji (`Super+.`) pickers. Only the shell, compositor and greeter change.

| desktopShell | Compositor | Shell | Greeter |
| --- | --- | --- | --- |
| dms | niri | DankMaterialShell | DMS greeter |
| noctalia (default) | niri | Noctalia | Noctalia greeter |
| gnome | Mutter | GNOME Shell | GDM |

The `gnome` option deliberately does _not_ use `services.desktopManager.gnome.enable`, which would pull in the full GNOME application suite. It assembles the session from `gnome-session`, `gnome-shell` and GDM instead, keeping the app set the same as the other two shells.

## Storage

The module pulls in [disko](https://github.com/nix-community/disko) and declares the whole partition table from `diskDevice`, `bootMode`, `rootFilesystem` and `swapSizeGiB`, so it expects to own the disk. Set these in your local flake before installing.

| Option | Type | Default |  |
| --- | --- | --- | --- |
| diskDevice | string | /dev/sda | install target |
| bootMode | uefi \| legacy | uefi | systemd-boot on an ESP, or GRUB on a BIOS boot partition plus an ext4 `/boot` |
| rootFilesystem | f2fs \| btrfs | f2fs | install-time; migrates nothing |
| compressionLevel | fast \| balanced \| max | fast | zstd 1 / 6 / 12; safe to change later |
| swapSizeGiB | int | 8 | 0 omits the partition (and hibernation) |

### f2fs or BTRFS

`f2fs` is what this module has always installed and is still the default. `btrfs` is where it is going, and is the better pick on a new install:

| | f2fs | btrfs |
| --- | --- | --- |
| compression | `compress_algorithm=zstd:N`, cluster scales with the level | `compress-force=zstd:N` in fixed 128 KB extents |
| freed space | fewer bytes written, but `df` does not move | returned to the filesystem — `df` moves |
| trim | `nodiscard` plus a daily `fstrim` timer | `discard=async`, no timer |
| layout | one flat root | `@`, `@home`, `@nix`, `@log` subvolumes |
| fsck | skipped (chokes on the `/nix` symlink count) | none to run at boot |

`rootFilesystem` is an install-time decision. disko derives the mkfs arguments, the mount options and the partition shape from it; it reformats nothing and migrates nothing, so changing it on an installed machine only changes which drivers and tools are in the closure. Get it right at install time, or reinstall.

`compressionLevel` is not install-time. Compression is recorded per extent (btrfs) or per cluster (f2fs), so a changed tier applies from the next write on and shows up as the store turns over. On btrfs, `btrfs filesystem defragment -r -czstd /` forces the issue.

### Swap

Two tiers. zram sits on top at priority 100 with lz4, so compressed RAM fills before anything reaches the disk; the `swapSizeGiB` partition underneath it is a hibernation target and a last-resort overflow, not a working set. disko marks it `resumeDevice`, so hibernation works without any `resume_offset` bookkeeping — which is the main reason this is a partition rather than a swapfile on the root. At `swapSizeGiB = 0` there is no partition, no `boot.resumeDevice`, and no hibernation: zram alone.

**Upgrading an existing install:** set `swapSizeGiB = 0`. Machines installed before this option existed have no swap partition on the disk, and a nonzero value emits a `swapDevices` entry plus a `boot.resumeDevice` pointing at a partition that is not there. Stage 1 waits 15s for a resume device that never appears and gives up; stage 2 leaves the swap unit failed without holding the boot for it. The machine comes up 15s slower with one unit red. A fresh install gets the partition and needs no such thing.

That graceful failure is not systemd's own behaviour, it is bought. `boot.resumeDevice` becomes `resume=` on the kernel command line, and given a `resume=` with no timeout supplied alongside it, `systemd-hibernate-resume-generator` writes `JobTimeoutSec=infinity` onto the device unit — then binds `systemd-hibernate-resume.service` to that device and orders it before `local-fs-pre.target`. A missing partition therefore stalls stage 1 permanently: root is never mounted, no unit fails, nothing is logged, and plymouth holds the splash over it. `modules/system/storage.nix` bounds that with `resumeflags=x-systemd.device-timeout=15s` and takes the swap unit off the critical path with `nofail`. Both are load-bearing.

## Installation

Follow these steps to install NixOS Micro Desktop:

1.  **Boot the NixOS installer**
    
    -   Download the latest NixOS ISO and boot the target machine from it
    -   Do not partition anything: the module declares the whole table through disko and formats the disk itself
2.  **Download and customize the sample flake**
    
    -   Copy the sample flake to `/etc/nixos/`:
        
        ```
        sudo curl -o /etc/nixos/flake.nix https://raw.githubusercontent.com/Avunu/nixos-micro-desktop/main/local/flake.nix
        ```
        
    -   Set at least `diskDevice`, `bootMode` and `rootFilesystem` — see [Storage](#storage) above
    -   Customize the flake according to your needs:
        
        ```
        sudo nano /etc/nixos/flake.nix
        ```
        
    -   Update the flake:
        
        ```
        sudo nix flake update /etc/nixos --extra-experimental-features nix-command flakes
        ```
        
3.  **Delete the old configuration.nix**
    
    -   Remove the old configuration file:
        
        ```
        sudo rm /etc/nixos/configuration.nix
        ```
        
4.  **Rebuild and reboot**
    
    -   Rebuild your system using the new flake:
        
        ```
        sudo nixos-rebuild switch --flake /etc/nixos#default
        ```
        
    -   Reboot your system to apply all changes:
        
        ```
        sudo reboot
        ```
        

## Customization

The beauty of NixOS Micro Desktop lies in its customizability. Feel free to modify the flake to add or remove packages, change system settings, or tweak the GNOME environment to your liking.

## Contributing

We welcome contributions! If you have improvements or bug fixes, please open a pull request or issue on our GitHub repository.

## Support

If you need help or have questions, please open an issue on our GitHub repository or join our community chat.

Enjoy your sleek, efficient, and customizable NixOS Micro Desktop!
