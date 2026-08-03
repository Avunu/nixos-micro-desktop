{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.microDesktop;
in
{
  config = {
    boot = {
      consoleLogLevel = mkDefault 0;
      initrd = {
        availableKernelModules = [
          "ahci"
          "ehci_pci"
          "nvme"
          "uhci_hcd"
        ];
        # fbcon is built into the kernel (not a loadable module), so it
        # must not be listed here — doing so breaks the modules-shrunk
        # initrd build. The framebuffer console is configured via the
        # `fbcon=vc:2-6` kernel parameter below.
        systemd = {
          enable = mkDefault true;
          tpm2.enable = mkDefault true;
        };
        verbose = mkDefault false;
      };
      kernelPackages = mkDefault pkgs.linuxPackages_latest;
      kernelParams = [
        "boot.shell_on_fail"
        "console=tty0"
        "fbcon=vc:2-6"
        # Note: i915.enable_guc removed - not all Intel GPUs support GuC/HuC
        # Add it per-device in local flake if needed (Gen9+ with firmware support)
        "i915.modeset=1"
        "i915.enable_fbc=1" # Framebuffer compression for power savings
        "loglevel=3"
        "mem_sleep_default=deep"
        "pcie_aspm.policy=powersupersave"
        "quiet"
        "rd.systemd.show_status=false"
        "systemd.show_status=false"
        "rd.udev.log_level=3"
        "splash"
        "udev.log_priority=3"
      ];
      loader = mkMerge [
        (mkIf (cfg.bootMode == "uefi") {
          efi = {
            canTouchEfiVariables = mkDefault true;
          };
          systemd-boot = {
            configurationLimit = mkDefault 10;
            enable = mkDefault true;
          };
        })
        (mkIf (cfg.bootMode == "legacy") {
          grub = {
            enable = mkDefault true;
          };
        })
        ({ timeout = mkDefault 2; })
      ];
      plymouth = {
        enable = mkDefault true;
      };
      supportedFilesystems = {
        ext3 = mkDefault false;
        ntfs3 = mkDefault false;
        xfs = mkDefault false;
        zfs = mkDefault false;
      };
      swraid = {
        enable = mkDefault false;
      };
      tmp = {
        cleanOnBoot = mkDefault true;
        useTmpfs = mkDefault false;
      };
    };

    console = {
      keyMap = mkDefault "us";
      packages = [ pkgs.terminus_font ];
    };

    disko = {
      devices = mkDefault {
        disk = {
          main = {
            content = mkMerge [
              (mkIf (cfg.bootMode == "uefi") {
                partitions = {
                  ESP = {
                    content = {
                      extraArgs = [
                        "-n"
                        "ESP"
                      ];
                      format = "vfat";
                      mountOptions = [
                        "noatime"
                        "umask=0077"
                      ];
                      mountpoint = "/boot";
                      type = "filesystem";
                    };
                    size = "1G";
                    type = "EF00";
                  };
                  root = {
                    content = {
                      extraArgs = [
                        "-O"
                        "extra_attr,compression" # Enable compression feature at format time
                        "-l"
                        "root"
                      ];
                      format = "f2fs";
                      mountOptions = [
                        "atgc"
                        "compress_algorithm=zstd:1" # Level 1: minimal CPU overhead, reduces I/O bandwidth
                        "compress_cache" # Cache decompressed pages for hot data (SQLite, desktop apps)
                        "compress_chksum"
                        "compress_extension=*" # Compress all files by default
                        # ...except frequently-rewritten small WAL/journal/lock files: recompressing
                        # a whole cluster on every tiny in-place-ish rewrite (SQLite/LevelDB WAL,
                        # systemd journal) is a known GC/checkpoint stall pattern under f2fs, worst
                        # when the volume is mostly full. See linux-f2fs-devel deadlock reports.
                        # f2fs mount options are comma-split at the top level, so each excluded
                        # extension needs its own repeated nocompress_extension=... entry — a single
                        # comma-joined value gets torn into unrecognized tokens and fails root mount.
                        # Each extension is also capped at 7 chars (F2FS_EXTENSION_LEN=8 incl. NUL) —
                        # "sqlite-wal"/"sqlite-shm" (10 chars) overflow that and get rejected with
                        # "invalid extension length/number", failing the mount entirely. Omitted below;
                        # rely on the shorter db-wal/db-shm convention instead.
                        "nocompress_extension=db"
                        "nocompress_extension=db-wal"
                        "nocompress_extension=db-shm"
                        "nocompress_extension=sqlite"
                        "nocompress_extension=ldb"
                        "nocompress_extension=log"
                        "nocompress_extension=journal"
                        "nocompress_extension=lock"
                        "gc_merge"
                        "noatime"
                        "nodiscard" # Use scheduled fstrim instead of synchronous discard
                      ];
                      mountpoint = "/";
                      type = "filesystem";
                    };
                    size = "100%";
                  };
                };
                type = "gpt";
              })
              (mkIf (cfg.bootMode == "legacy") {
                partitions = {
                  boot = {
                    size = "1M";
                    type = "EF02";
                  };
                  root = {
                    content = {
                      extraArgs = [
                        "-O"
                        "extra_attr,compression" # Enable compression feature at format time
                        "-l"
                        "root"
                      ];
                      format = "f2fs";
                      mountOptions = [
                        "atgc"
                        "compress_algorithm=zstd:1" # Level 1: minimal CPU overhead, reduces I/O bandwidth
                        "compress_cache" # Cache decompressed pages for hot data (SQLite, desktop apps)
                        "compress_chksum"
                        # "compress_extension=*" # Compress all files by default
                        "gc_merge"
                        "noatime"
                        "nodiscard" # Use scheduled fstrim instead of synchronous discard
                      ];
                      mountpoint = "/";
                      type = "filesystem";
                    };
                    size = "100%";
                  };
                };
                type = "gpt";
              })
            ];
            device = cfg.diskDevice;
            type = "disk";
          };
        };
      };
    };

    fileSystems = {
      "/" = {
        # disable fsck with f2fs until it runs correctly with the large amount of /nix symlinks
        noCheck = mkDefault true;
      };
    };

    zramSwap = {
      enable = mkDefault true;
    };
  };
}
