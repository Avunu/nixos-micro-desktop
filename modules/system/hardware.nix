{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.microDesktop;

  # Firmware trees for hardware this desktop will never run on. linux-firmware
  # is 1.8 GB unpacked (769 MB after the zstd pass NixOS applies) and is the
  # single largest thing in the closure — larger than the kernel, its modules
  # and every GTK library combined. Roughly half of it is for datacenter NICs
  # and phone SoCs.
  #
  # Every GPU tree stays (amdgpu, nvidia, radeon, i915, xe), and so does every
  # wifi and bluetooth tree. Note that Qualcomm's *wifi* firmware lives in
  # separate top-level directories (ath10k, ath11k, ath12k, qca) which are
  # kept — `qcom` below is only the SoC platform firmware for phones, SBCs and
  # Windows-on-ARM laptops, none of which can run this x86_64 config.
  firmwareExclusions = [
    "bnx2x" # 2.6M  — Broadcom NetXtreme II server NICs
    "cxgb4" # 4.6M  — Chelsio T4/T5 datacentre NICs
    "dpaa2" # 15M   — NXP DPAA2 embedded networking
    "liquidio" # 4.9M  — Cavium LiquidIO datacentre NICs
    "mellanox" # 107M  — Mellanox datacentre NICs
    "netronome" # 141M  — Netronome SmartNICs
    "qcom" # 462M  — Qualcomm SoCs: phones, SBCs, Windows-on-ARM
    "qed" # 21M   — QLogic FastLinQ datacentre NICs
  ];

  # Nested exclusions, removed after the copy rather than skipped during it.
  # The copy loop below works on top-level entries, and mrvl/ is the one tree
  # worth splitting: 72M of it is Prestera datacentre switch firmware while the
  # rest is Marvell wifi/bluetooth for laptops and Chromebooks.
  firmwareNestedExclusions = [
    "mrvl/prestera" # 72M — Marvell Prestera datacentre switch ASICs
  ];
in
{
  config = {
    # ── Closure trims applied as package overrides ────────────────
    nixpkgs.overlays = [
      (_final: prev: {
        # Trim linux-firmware.
        #
        # Overriding the PACKAGE rather than `hardware.firmware`: that option
        # is a list NixOS also fills with the small odd firmwares (ipw2200,
        # rt5677, zd1211, rtl8192su, rtl8761b for USB bluetooth). mkForce over
        # the list would take those with it; this leaves the list alone.
        #
        # The trim is applied to the COMPRESSED package and compression is then
        # declined. NixOS runs every firmware package through
        # compressFirmwareZstd — zstd -19 over 1.8 GB. Doing it in this order
        # means the expensive half is the one Hydra already built and the binary
        # cache already has; `passthru.compressFirmware = false` is the udev
        # module's own opt-out (services/hardware/udev.nix) and is what stops it
        # being redone locally on every bump.
        #
        # Exclusions rather than an allow-list, deliberately: 585 firmware files
        # sit loose at the top of lib/firmware (iwlwifi's .ucode among them) and
        # more sit in small directories nobody thinks to name. An allow-list has
        # to be complete, and the failure mode for an incomplete one is a device
        # that silently does not work.
        linux-firmware =
          let
            # The exact derivation the udev module would have produced, so this
            # is a cache hit rather than a local zstd -19 run.
            compressed = prev.compressFirmwareZstd prev.linux-firmware;
          in
          prev.runCommand "linux-firmware-desktop"
            {
              passthru = {
                compressFirmware = false;
                inherit (prev.linux-firmware) version;
              };
              inherit (prev.linux-firmware) meta;
            }
            ''
              # A real copy, and it has to be. Symlinks would still point at the
              # full package and keep every byte of it in the closure — saving
              # nothing — and hard links are refused outright, since nix
              # bind-mounts the store into the build sandbox as a separate
              # device ("Invalid cross-device link").
              #
              # So this writes the ~950 MB it keeps. That is I/O, not
              # compression and not compilation, and it happens once per
              # linux-firmware bump. Copying only the kept entries rather than
              # copying everything and deleting after is the difference between
              # writing 950 MB and writing 1.8 GB.
              #
              # Internal symlinks are relative (compressFirmwareZstd keeps them
              # that way), so they survive the copy and carry no reference back
              # to the original.
              mkdir -p $out/lib/firmware
              for entry in ${compressed}/lib/firmware/*; do
                case " ${concatStringsSep " " firmwareExclusions} " in
                  *" $(basename "$entry") "*) continue ;;
                esac
                cp -r "$entry" $out/lib/firmware/
              done
              chmod -R u+w $out/lib/firmware
              ${concatMapStringsSep "\n" (p: ''rm -rf "$out/lib/firmware/${p}"'') firmwareNestedExclusions}
            '';

        # Ship one mbrola voice per language instead of all of them: 644 MB
        # down to 260 MB, and the 644 MB version is the second largest thing on
        # the system.
        #
        # Nothing here asked for this. NixOS turns on services.speechd for any
        # graphical desktop (services/misc/graphical-desktop.nix), speechd's
        # espeak-ng module links mbrola, and mbrola pulls its full voice
        # database. No screen reader is installed by default, so on a stock
        # install every byte of it is unreachable — but speechd stays enabled so
        # that installing Orca from the software centre still works.
        #
        # This is nixpkgs' own fix for the same problem; see
        # nixos/modules/profiles/installation-device.nix.
        mbrola-voices = prev.mbrola-voices.override {
          languages = [ "*1" ];
        };
      })
    ];

    hardware = {
      bluetooth = {
        enable = mkDefault true;
      };
      enableRedistributableFirmware = mkDefault true;
      graphics = {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver
          intel-vaapi-driver
          ocl-icd
          vulkan-loader
        ];
      };
      sane = {
        enable = mkDefault cfg.enableScanning;
        extraBackends = with pkgs; [
          sane-airscan
          sane-backends
        ];
      };
      sensor = {
        iio = {
          enable = mkDefault true;
        };
      };
    };

    powerManagement = {
      enable = mkDefault true;
      powertop = {
        enable = mkDefault false;
      };
    };

    services = {
      # bpftune dynamically overrides swappiness/watermarks at runtime,
      # which conflicts with zram tuning. Disabled until per-sysctl
      # exclusion is supported upstream.
      bpftune = {
        enable = mkDefault false;
      };
      colord = {
        enable = mkDefault true;
      };
      fprintd = {
        enable = mkDefault cfg.enableFingerprint;
        package = mkDefault pkgs.fprintd-tod;
        tod = {
          driver = mkDefault pkgs.libfprint-2-tod1-goodix;
          enable = mkDefault cfg.enableFingerprint;
        };
      };
      # services.fstrim lives in system/storage.nix: whether a timer-driven
      # trim is wanted at all follows from the root filesystem's discard mount
      # option, which follows from microDesktop.rootFilesystem.
      fwupd = {
        enable = mkDefault true;
      };
      journald = {
        # systemd's default is 10% of the filesystem, capped at 4 GB, which on
        # a modern disk means the journal grows to gigabytes of archived boots
        # before anything reclaims it. The hourly rebuild in system/nix.nix
        # makes this system unusually chatty, so bound it explicitly.
        extraConfig = mkDefault ''
          SystemMaxUse=512M
          SystemMaxFileSize=64M
        '';
      };
      kmscon = {
        config = {
          hwaccel = mkDefault true;
        };
        enable = mkDefault true;
      };
      libinput = {
        enable = mkDefault true;
      };
      # Nothing here writes to /var/log. The generated logrotate config has two
      # stanzas, both monthly, for /var/log/btmp and /var/log/wtmp — and NixOS
      # schedules it hourly and runs a config check at every boot and every
      # nixos-rebuild switch, which on this system is also hourly. journald
      # bounds its own storage above.
      logrotate = {
        enable = mkDefault false;
      };
      power-profiles-daemon = {
        enable = mkDefault true;
      };
      udev = {
        # I/O scheduler selection, which is really about making IOWeight= mean
        # something.
        #
        # BFQ is the only multi-queue scheduler that implements io.weight, so
        # the IOWeight= settings on nix-daemon and system-upgrade (system/nix.nix)
        # and on the compositor units are decorative on any device running
        # mq-deadline — which is what SATA SSDs and eMMC fall back to. NixOS's
        # own nix-optimise unit has the same problem: its IOSchedulingClass=idle
        # is honoured by BFQ and ignored by mq-deadline.
        #
        # NVMe is left at "none" on purpose. Its queue depth makes starvation
        # unlikely and BFQ's single-queue serialization costs real throughput
        # there; the tradeoff that makes sense on a SATA link does not on four
        # PCIe lanes. IOWeight= is a no-op on those devices, knowingly.
        extraRules = ''
          ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
          ACTION=="add|change", SUBSYSTEM=="block", KERNEL!="nvme[0-9]n[0-9]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}=="?*", ATTR{queue/scheduler}="bfq"
        '';
      };
      udisks2 = {
        enable = mkDefault true;
      };
      upower = {
        enable = mkDefault true;
      };
    };
  };
}
