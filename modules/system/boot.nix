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
        # Every disk controller this desktop might install to, because
        # nothing generates a hardware-configuration.nix for it: the
        # installer ISO loads every driver and sees the disk, then the
        # installed initrd has only these plus NixOS's defaults (ahci, nvme,
        # sd_mod, mmc_block, USB HID) — and with the controller's driver
        # missing, stage 1 times out on /dev/disk/by-partlabel/disk-main-*
        # for a disk that is right there. Detecting the hardware at install
        # time is not an option: the install is offline, and a different
        # module list is a different initrd, which the ISO does not carry.
        # Only the listed modules and their dependencies land in the initrd.
        availableKernelModules = [
          "ahci"
          "ehci_pci"
          "nvme"
          "uhci_hcd"
          # Intel VMD (Volume Management Device), on by default on many
          # Intel workstations and laptops: the NVMe drive sits in a PCI
          # domain only vmd exposes, so without it nvme never sees the disk
          # (a Dell C620 workstation with a WD SN5100 behind VMD did exactly
          # that).
          "vmd"
          # eMMC: mmc_block (a NixOS default) needs a host controller driver
          # to have anything to talk to.
          "sdhci_pci"
          "sdhci_acpi"
          # USB-attached disks.
          "usb_storage"
          "uas"
          # Virtual machines (qemu/KVM, Proxmox, libvirt).
          "virtio_pci"
          "virtio_blk"
          "virtio_scsi"
        ];
        # fbcon is built into the kernel (not a loadable module), so it
        # must not be listed here — doing so breaks the modules-shrunk
        # initrd build. The framebuffer console is configured via the
        # `fbcon=vc:2-6` kernel parameter below.
        systemd = {
          tpm2.enable = mkDefault true;
        };
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
        # The kernel default is "always", which leaves khugepaged compacting
        # memory in the background to keep huge pages available for processes
        # that never asked for them. On an interactive desktop that background
        # compaction is felt as latency, which is why Fedora and Ubuntu both
        # ship "madvise" instead: applications that benefit still get huge
        # pages by asking for them.
        "transparent_hugepage=madvise"
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
      # boot.supportedFilesystems lives in system/storage.nix: which drivers
      # and tools are worth carrying follows from microDesktop.rootFilesystem.
      swraid = {
        enable = mkDefault false;
      };
      # /tmp on tmpfs. The root filesystem carries transparent zstd
      # compression under either microDesktop.rootFilesystem, so every
      # short-lived temp file written there would be compressed on the way in
      # and decompressed on the way out, and then discarded. That is the worst
      # case for those settings. It also makes the SQLITE_TMPDIR="/tmp" in
      # desktop/common.nix mean what its comment says.
      #
      # Paired with systemd.services.nix-daemon.environment.TMPDIR="/var/tmp"
      # in system/nix.nix: tmpfs pages are charged to the cgroup that allocated
      # them, so build scratch left on /tmp would count against nix-daemon's
      # memory ceiling. The two settings have to move together.
      tmp = {
        cleanOnBoot = mkDefault true;
        useTmpfs = mkDefault true;
      };
    };

    console = {
      keyMap = mkDefault "us";
      # No console.packages: it used to carry terminus_font, which was never
      # loaded. console.font is not set anywhere here, and services.kmscon
      # (see system/hardware.nix) replaces the kernel VT console outright, so
      # the consolefonts were installed on every machine and read by nothing.
    };
  };
}
