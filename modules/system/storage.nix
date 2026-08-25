{
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.microDesktop;

  # ── Root filesystem profiles (rootFilesystem / compressionLevel) ──
  #
  # Everything that has to be decided before the disk exists lives here.
  # Two profiles, one of which is on the way out: f2fs is what this
  # module has always installed, btrfs is where it is going. They are
  # kept side by side rather than switched over at once because the
  # choice is install-time and migrates nothing — an existing machine
  # keeps whatever it was formatted with, and only a reinstall moves it.
  #
  # When btrfs becomes the default, flipping `rootFilesystem`'s default
  # in options.nix is the whole change; when f2fs is retired, deleting
  # the `f2fs` branch of `rootProfile` and its entry in
  # `boot.supportedFilesystems` is the whole change.

  # zstd level, shared by both filesystems. btrfs takes 1-15 and f2fs
  # 1-22, so the same three tiers are expressible on either.
  zstdLevel =
    {
      fast = 1;
      balanced = 6;
      max = 12;
    }
    .${cfg.compressionLevel};

  # f2fs compression cluster size, in log2 blocks: 2 = 16KB, 3 = 32KB,
  # 4 = 64KB. See the compress_log_size comment in the f2fs profile below
  # for why it moves with the level. btrfs needs no equivalent.
  f2fsClusterLog =
    {
      fast = 2;
      balanced = 3;
      max = 4;
    }
    .${cfg.compressionLevel};

  rootProfile =
    {
      btrfs = {
        # compress-force, not compress: btrfs's heuristic samples the
        # *first* blocks of a file and, if they look incompressible,
        # marks the whole file to skip compression permanently. For an
        # ELF binary behind an incompressible header that is the wrong
        # call, made once, for the life of the file. Forcing it only
        # costs attempts — btrfs still stores the extent raw whenever
        # compressing it would not be smaller.
        #
        # ssd/nossd and space_cache=v2 go unstated: btrfs picks the
        # first up from queue/rotational (the same flag the udev rules
        # in system/hardware.nix key on) and the second is the kernel
        # default now.
        mountOptions = [
          "compress-force=zstd:${toString zstdLevel}"
          # Async discard batches freed extents and trickles them out.
          # It replaces the nodiscard + daily fstrim posture the f2fs
          # root carries, because on cheap eMMC a batched
          # whole-filesystem trim is precisely the multi-second stall
          # this system works to avoid. Also btrfs's own default since
          # 6.2 — stated anyway, since the fstrim timer it displaces
          # has to be switched off by hand (see services.fstrim below).
          "discard=async"
          # Store small files inside the metadata b-tree rather than
          # giving each one a 4KB block of its own. A Nix store is
          # mostly small files, so this is not a rounding error.
          #
          # It is only correct next to -m single below. Inline data
          # lives in metadata, so under the DUP metadata mkfs.btrfs
          # defaults to, every inlined byte is written twice and
          # anything past ~2KB costs more inlined than it would as a
          # plain block — which is why the kernel's own default is 2048
          # and not the sectorsize. Raise one without the other and
          # small files get bigger.
          "max_inline=4096"
          "noatime"
        ];
        extraArgs = [
          "-L"
          "root"
          "-d"
          "single"
          # single, not the DUP that mkfs.btrfs has defaulted to for
          # single-device filesystems since 5.15. Two reasons: it is
          # what makes max_inline=4096 pay, and the redundancy DUP buys
          # is aimed at bad sectors, which is how a platter fails, not
          # flash. This desktop installs to flash. The man page asks for
          # both profiles to be stated explicitly rather than inferred,
          # which is why -d is here too even though single is already
          # its default.
          "-m"
          "single"
        ];
      };
      f2fs = {
        mountOptions = [
          "atgc"
          "compress_algorithm=zstd:${toString zstdLevel}"
          # Cluster size, in log2 blocks: 2 = 16KB, 3 = 32KB, 4 = 64KB.
          # Unlike btrfs — which compresses in a fixed 128KB extent and
          # so needs one number — f2fs gains ratio at the higher zstd
          # levels only if the cluster grows with them, because zstd has
          # more history to work against. It is paid for on the read
          # side: any read decompresses the whole cluster it lands in.
          "compress_log_size=${toString f2fsClusterLog}"
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
        extraArgs = [
          "-O"
          "extra_attr,compression" # Enable compression feature at format time
          "-l"
          "root"
        ];
      };
    }
    .${cfg.rootFilesystem};

  # ── Root partition content ──────────────────────────────────────
  #
  # The two filesystems take different shapes in disko: f2fs is a plain
  # `filesystem` with one mountpoint, btrfs is its own content type with
  # subvolumes underneath it.
  #
  # The subvolumes are what btrfs is here for beyond compression. Every
  # mountpoint carries the same options — they are filesystem-wide on
  # btrfs anyway, so this is documentation as much as configuration —
  # and the split exists so that a snapshot of @ is the system without
  # dragging /nix (which nix already versions) or /home (which is the
  # part you want restored separately) along with it.
  #
  # /nix and /var/log are both in nixpkgs' pathsNeededForBoot, so NixOS
  # marks them neededForBoot on its own and stage 1 mounts them. No
  # extra wiring here.
  rootContent =
    if cfg.rootFilesystem == "btrfs" then
      {
        type = "btrfs";
        inherit (rootProfile) extraArgs;
        subvolumes = {
          "@" = {
            mountOptions = rootProfile.mountOptions;
            mountpoint = "/";
          };
          "@home" = {
            mountOptions = rootProfile.mountOptions;
            mountpoint = "/home";
          };
          "@nix" = {
            mountOptions = rootProfile.mountOptions;
            mountpoint = "/nix";
          };
          "@log" = {
            mountOptions = rootProfile.mountOptions;
            mountpoint = "/var/log";
          };
        };
      }
    else
      {
        type = "filesystem";
        format = "f2fs";
        inherit (rootProfile) extraArgs mountOptions;
        mountpoint = "/";
      };

  # How long either boot stage may wait for the swap partition before it
  # gives up and carries on without it. Both places that consume this are
  # guarding the same case — a `swapSizeGiB` above 0 on a disk that has no
  # such partition — and neither of them bounds the wait on its own.
  #
  # 15s is chosen against the only wait that is real: the swap partition
  # lives on the same disk as the root filesystem, so if the disk has
  # enumerated at all the partition is already there. The number only has
  # to outlast enumeration on a slow controller, not cover a device that
  # might still show up.
  swapDeviceTimeout = "15s";

  # ── Partitions shared by both boot modes ────────────────────────
  #
  # Defined once here because the uefi and legacy tables differ only in
  # what comes *before* them (an ESP, versus a BIOS boot partition plus
  # an ext4 /boot) — and because keeping two copies is how the legacy
  # branch ended up silently missing compress_extension and the whole
  # nocompress_extension list.
  swapPartition = {
    size = "${toString cfg.swapSizeGiB}G";
    content = {
      type = "swap";
      resumeDevice = true;
      # fstrim(8) walks mounted filesystems and never touches a swap
      # partition, so swapon's own discard is the only thing that ever
      # trims this area. "once" does it at swapon and then leaves the
      # device alone, rather than issuing a discard on every page freed.
      discardPolicy = "once";
      # Stage 2's half of the missing-partition guard; see the resumeflags
      # comment on boot.kernelParams below for stage 1's, which is the one
      # that actually hangs.
      #
      # These reach fstab as the swap entry's options, where nofail moves
      # the generated .swap unit out of swap.target.requires and into
      # swap.target.wants — a swap device that is not there stops being a
      # failure of swap.target — and the device timeout replaces systemd's
      # 90s default wait on the .device unit. disko also passes these to
      # `swapon --options=` when it first activates the partition, which
      # ignores both (verified against util-linux 2.42): nofail there does
      # not suppress a genuine install-time error.
      mountOptions = [
        "defaults"
        "nofail"
        "x-systemd.device-timeout=${swapDeviceTimeout}"
      ];
    };
  };

  rootPartition = {
    size = "100%";
    content = rootContent;
  };

  # Ordering is disko's job, not the attribute names': it sorts by the
  # partition's `priority`, which defaults to 9001 for size = "100%".
  # Root is therefore created last whether or not swap is present, so
  # dropping the swap partition at swapSizeGiB = 0 needs nothing else.
  diskPartitions =
    optionalAttrs (cfg.swapSizeGiB > 0) {
      swap = swapPartition;
    }
    // {
      root = rootPartition;
    };
in
{
  config = {
    boot = {
      # `resumeDevice = true` on the swap partition above becomes
      # `boot.resumeDevice`, which — because boot.initrd.systemd is on, see
      # system/boot.nix — nixpkgs puts on the kernel command line as
      # `resume=/dev/disk/by-partlabel/disk-main-swap`. In stage 1
      # systemd-hibernate-resume-generator reads that and writes a drop-in
      # on the matching .device unit. Its fallback, when nothing supplies a
      # timeout, is `JobTimeoutSec=infinity`.
      #
      # That is not a slow path, it is a stuck one. The generator also binds
      # systemd-hibernate-resume.service to that device with BindsTo= and
      # orders it Before=local-fs-pre.target, so on a disk with no such
      # partition stage 1 waits on a device job that can never time out:
      # the root filesystem is never mounted, nothing fails, nothing is
      # logged, and behind plymouth there is not even a message. Every
      # machine installed before swapSizeGiB existed is that disk.
      #
      # resumeflags= is the documented channel for handing that generator
      # mount options (systemd-hibernate-resume-generator(8)), and
      # x-systemd.device-timeout= is the only one that means anything for a
      # swap device: supplied, it writes JobRunningTimeoutSec= instead and
      # the wait becomes finite. It defaults to rootflags=, which is unset
      # here — root comes from fstab — so nothing is being displaced.
      kernelParams = mkIf (cfg.swapSizeGiB > 0) [
        "resumeflags=x-systemd.device-timeout=${swapDeviceTimeout}"
      ];

      # The root filesystem in use is added to this set automatically —
      # nixpkgs derives it from `fileSystems` at normal priority, which
      # would quietly override an mkDefault false here — so the one that
      # is mounted arrives on its own regardless. The point of naming
      # both is the *other* one: it keeps the unused driver, its initrd
      # module and its userspace tools (btrfs-progs / f2fs-tools) off a
      # machine that will never mount it. ext3 is covered by the ext4
      # driver either way, and ext4 itself stays because legacy boot
      # puts /boot on it.
      supportedFilesystems = {
        btrfs = mkDefault (cfg.rootFilesystem == "btrfs");
        ext3 = mkDefault false;
        f2fs = mkDefault (cfg.rootFilesystem == "f2fs");
        ntfs3 = mkDefault false;
        xfs = mkDefault false;
        zfs = mkDefault false;
      };
    };

    # ── Disk layout (disko) ───────────────────────────────────────
    #
    # Only the leading partitions differ between the boot modes. Swap
    # and root are the same table either way and come from
    # diskPartitions above, which is also where rootFilesystem picks the
    # root filesystem and swapSizeGiB sizes (or removes) the swap.
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
                }
                // diskPartitions;
                type = "gpt";
              })
              (mkIf (cfg.bootMode == "legacy") {
                partitions = {
                  bios = {
                    size = "1M";
                    type = "EF02";
                  };
                  # GRUB reads ext4 natively and completely, which is
                  # not something to lean on for either root filesystem
                  # here: its f2fs driver cannot read transparent
                  # compression at all, and its btrfs driver has to be
                  # trusted with zstd extents and a subvolume layout
                  # this module picks freely. A small ext4 /boot keeps
                  # GRUB's modules and kernels somewhere it is certain
                  # to reach them, and means the root filesystem is
                  # never the bootloader's problem — which is what lets
                  # the profiles above choose compression and layout on
                  # the merits.
                  #
                  # This is also why the legacy f2fs root can now carry
                  # compress_extension=*, which it could not while GRUB
                  # was reading kernels off it directly.
                  boot = {
                    content = {
                      extraArgs = [
                        "-L"
                        "boot"
                      ];
                      format = "ext4";
                      mountOptions = [ "noatime" ];
                      mountpoint = "/boot";
                      type = "filesystem";
                    };
                    size = "1G";
                    type = "8300";
                  };
                }
                // diskPartitions;
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
        # f2fs fsck does not run correctly against the large number of
        # /nix symlinks, and btrfs has no boot-time fsck to run at all.
        noCheck = mkDefault true;
      };
    };

    services = {
      # f2fs mounts nodiscard and relies on this timer; btrfs mounts
      # discard=async and releases extents as they are freed, which is
      # steadier and spares a cheap eMMC the multi-second stall a
      # batched whole-filesystem pass can produce. NixOS enables the
      # timer by default, so the btrfs case has to switch it off rather
      # than merely not switch it on.
      #
      # Either way it never covered swap: fstrim walks mounted
      # filesystems and never sees a swap partition, which is why that
      # partition carries discardPolicy = "once" above.
      fstrim = {
        enable = mkDefault (cfg.rootFilesystem == "f2fs");
        interval = mkDefault "daily";
      };
    };

    # ── zram ──────────────────────────────────────────────────────
    zramSwap = {
      enable = mkDefault true;
      # lz4 rather than the zstd default. For a swap device the number
      # that matters is how long a fault takes to come back, not how
      # small the page got: zstd compresses perhaps 30% better and costs
      # several times as much CPU to decompress, and on these machines
      # that CPU is the scarce resource. Compressed swap is only worth
      # having while reading it back stays cheaper than reading the disk
      # it replaces.
      algorithm = mkDefault "lz4";
      # Explicit because the ordering carries weight: zram has to
      # outrank the disk swap partition disko creates (which lands at
      # priority -1), or the kernel will page out to the disk while
      # compressed RAM sits unused.
      priority = mkDefault 100;
    };
  };
}
