{ lib, ... }:
with lib;
{
  options = {
    microDesktop = {
      bootMode = mkOption {
        default = "uefi";
        description = "Boot mode: uefi (systemd-boot) or legacy (GRUB)";
        type = types.enum [
          "uefi"
          "legacy"
        ];
      };
      compressionLevel = mkOption {
        default = "fast";
        description = ''
          How hard the root filesystem compresses. Applies under both
          `rootFilesystem` values — the zstd level is the one knob the two
          have in common, and the tiers mean the same thing on either.

          - `fast`: zstd level 1. Close to free on the CPU, and already most
            of the win — on a real Nix store level 1 alone accounts for
            roughly half the bytes in the files large enough to compress.
            The right answer on any machine whose disk is not the binding
            constraint.
          - `balanced`: zstd level 6.
          - `max`: zstd level 12. For the case this option exists for — a
            small soldered eMMC, where the disk runs out long before the
            patience does.

          What the tiers trade is write throughput, and on these CPUs that
          is the part to think about: zstd's own figures put level 12 at
          well under a tenth of level 1's compression speed. `max` suits a
          machine that substitutes its packages from the binary cache; it is
          a poor fit for one that builds them. Reads cost the same at every
          level.

          Unlike `rootFilesystem`, safe to change on an installed machine.
          Compression is recorded per extent (btrfs) or per cluster (f2fs),
          so what is already written keeps decompressing exactly as before
          and the new level applies from the next write on. Nothing is
          recompressed in place — a changed tier shows up as the store turns
          over, or immediately on a fresh install. On btrfs,
          `btrfs filesystem defragment -r -czstd` forces the issue.

          On f2fs this also moves the compression cluster size (16/32/64 KB),
          because f2fs only gains ratio at the higher levels if zstd has more
          history to work against. btrfs compresses in a fixed 128 KB extent
          and needs no equivalent.
        '';
        type = types.enum [
          "fast"
          "balanced"
          "max"
        ];
      };
      desktopShell = mkOption {
        default = "noctalia";
        description = ''
          Which desktop shell to run.

          - `gnome`: GNOME Shell on Mutter, with GDM.
          - `dms`: DankMaterialShell on niri, with the DMS greeter.
          - `noctalia`: Noctalia on niri, with the Noctalia greeter.

          All three share the same GNOME core apps and services; only the
          shell, compositor and greeter differ. `noctalia` is the default
        '';
        type = types.enum [
          "gnome"
          "dms"
          "noctalia"
        ];
      };
      diskDevice = mkOption {
        default = "/dev/sda";
        description = "Disk device for installation";
        type = types.str;
      };
      # The four enable* options below carry `visible = false`, which keeps
      # them out of the installer wizard. nixos-install-helper derives its
      # prompts from this option tree (see lib/options-to-schema.nix), so every
      # visible option becomes a question someone has to answer during install.
      # These four are closure trims for capabilities most machines do not need
      # — a consumer flake can still set them, but nobody should be asked about
      # a fingerprint reader at the install prompt.
      enableAppImage = mkOption {
        default = false;
        description = ''
          Register the AppImage MIME handler and the FHS runtime that executes
          them.

          Off by default, and the reason is worth stating because it is not
          obvious from the size of the feature. `buildFHSEnv` puts the full
          glibc locale archive — 222 MB, every locale glibc supports — into the
          sandbox rootfs at /usr/lib/locale, so that an AppImage asking for any
          locale finds one. It takes it from `pkgs.glibcLocales` directly,
          which means it ignores `i18n.supportedLocales`: this system trims its
          own archive to two locales and 2 MB, and then AppImage support hands
          the other 220 MB back.

          There is no cheap way to align the two. Overriding `glibcLocales`
          globally takes the whole system off the binary cache (measured: 3422
          derivations rebuilt from source), and threading a trimmed archive
          into `buildFHSEnv` alone defeats callPackage's splicing, which
          rebuilds glibc and gcc locally and returns only 165 MB of the 222.

          Software here installs through GNOME Software and the nix-profile
          PackageKit backend, so AppImage is a fallback path rather than the
          main one. Set this to true if you need it; it is one line and the
          cost is understood.
        '';
        type = types.bool;
        visible = false;
      };
      enableFileIndexing = mkOption {
        default = false;
        description = ''
          Index the user's files for content search (localsearch/tinysparql).

          Off by default: the indexer walks and re-reads $HOME on a schedule
          and adds ~400 MB to the closure. With it off, Nautilus search still
          matches file names, just not file contents.
        '';
        type = types.bool;
        visible = false;
      };
      enableFingerprint = mkOption {
        default = false;
        description = ''
          Enable fingerprint authentication (fprintd with the Goodix TOD driver).

          Off by default: the driver is specific to one Goodix sensor family and
          costs ~300 MB on every machine, including the ones with no reader.
        '';
        type = types.bool;
        visible = false;
      };
      enableScanning = mkOption {
        default = false;
        description = ''
          Enable scanner support (SANE, with the airscan/eSCL backend).

          Off by default: the backend collection is ~230 MB of per-vendor
          drivers. Most modern network MFPs work over airscan alone.
        '';
        type = types.bool;
        visible = false;
      };
      enableSsh = mkOption {
        default = false;
        description = "Enable SSH server";
        type = types.bool;
      };
      enableVpn = mkOption {
        default = false;
        description = "Enable VPN support (installs NetworkManager VPN plugins)";
        type = types.bool;
      };
      extraPackages = mkOption {
        default = [ ];
        description = "Additional packages to install";
        type = types.listOf types.package;
      };
      hostName = mkOption {
        default = "nixos";
        description = "Hostname for the system";
        type = types.str;
      };
      initialPassword = mkOption {
        default = "password";
        description = "Initial password for the user";
        type = types.str;
      };
      locale = mkOption {
        default = "en_US.UTF-8";
        description = "System locale";
        type = types.str;
      };
      rootFilesystem = mkOption {
        default = "f2fs";
        description = ''
          Which filesystem to put on the root partition.

          - `f2fs`: a flat root with transparent zstd compression, a daily
            fstrim and `nodiscard`. What this module has always installed.
          - `btrfs`: zstd compression via `compress-force`, `discard=async`,
            small files inlined into a single-profile metadata tree, and an
            `@` / `@home` / `@nix` / `@log` subvolume layout.

          `f2fs` is still the default, but `btrfs` is where this module is
          going: it returns what compression saves to `df` rather than only
          writing fewer bytes, it has subvolumes and snapshots, and it has a
          fsck worth running. Set it to `btrfs` on new installs unless you
          have a reason not to.

          Note what this option is NOT. It is an install-time decision: disko
          derives the mkfs arguments, the mount options and the partition
          content shape from it. It migrates nothing and reformats nothing,
          so changing it on an installed machine changes only which
          filesystem drivers and tools are in the closure — the disk keeps
          whatever it was formatted with. Get it right at install time, or
          reinstall.
        '';
        type = types.enum [
          "f2fs"
          "btrfs"
        ];
      };
      sshPasswordAuth = mkOption {
        default = true;
        description = "Allow password authentication for SSH";
        type = types.bool;
      };
      sshRootLogin = mkOption {
        default = "yes";
        description = "Permit root login via SSH";
        type = types.str;
      };
      stateVersion = mkOption {
        default = "25.11";
        description = "NixOS state version";
        type = types.str;
      };
      swapSizeGiB = mkOption {
        default = 8;
        description = ''
          Size of the disk swap partition, in GiB. 0 leaves it out entirely.

          This is the second swap tier, not the first: zram sits above it at
          priority 100 (see `zramSwap` in system/storage.nix), so the kernel
          fills compressed RAM before it touches the disk. What the partition
          actually buys is hibernation, which needs a resume device at least
          as large as RAM, plus somewhere to go when zram is full instead of
          the OOM killer.

          Which makes 8 GiB a default, not a recommendation. Size it against
          the machine in front of you: at least RAM if you want hibernation
          to work, and rather less than 8 GiB is reasonable on a small disk
          where the space is worth more than a tier that is only reached
          under real pressure. At 0 there is no swap partition, no
          `swapDevices` entry, no `boot.resumeDevice` and no hibernation —
          zram alone.

          Install-time, like `rootFilesystem`, but harmless to change
          afterwards rather than dangerous: nothing repartitions on rebuild,
          so a new value simply has no effect on an installed machine. The
          one exception is 0, which drops the `swapDevices` entry and so
          stops activating a partition that is still sitting on the disk.

          Which is the setting an *existing* machine wants, and the one
          upgrade note on this whole option. Installs made before this option
          existed have no swap partition on the disk, but a nonzero value
          still emits a `swapDevices` entry and a `boot.resumeDevice`
          pointing at `/dev/disk/by-partlabel/disk-main-swap`. Nothing there
          will find it. Stage 1 waits 15s for a resume device that is not
          coming and gives up; stage 2 leaves the swap unit failed but does
          not hold the boot for it. The machine comes up — 15s slower, with
          a unit red in `systemctl --failed`.

          It degrades that way only because `system/storage.nix` makes it:
          `resumeflags=x-systemd.device-timeout=` on the kernel command line
          bounds stage 1, `nofail` on the fstab entry unblocks stage 2.
          Without the first, stage 1 does not fail — it hangs, silently and
          forever. Read the comment on `boot.kernelParams` there before
          touching either.

          Set this to 0 on any machine installed before the partition
          existed, or reinstall to get one.
        '';
        type = types.ints.unsigned;
      };
      timeZone = mkOption {
        default = "America/New_York";
        description = "System timezone";
        type = types.str;
      };
      username = mkOption {
        default = "user";
        description = "Primary user name";
        type = types.str;
      };
    };
  };
}
