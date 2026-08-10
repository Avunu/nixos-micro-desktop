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
      # The three enable* options below carry `visible = false`, which keeps
      # them out of the installer wizard. nixos-install-helper derives its
      # prompts from this option tree (see lib/options-to-schema.nix), so every
      # visible option becomes a question someone has to answer during install.
      # These three are closure trims for hardware most machines do not have —
      # a consumer flake can still set them, but nobody should be asked about a
      # fingerprint reader at the install prompt.
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
