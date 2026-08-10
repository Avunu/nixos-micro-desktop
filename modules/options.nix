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
