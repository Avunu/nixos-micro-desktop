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
        default = "dms";
        description = ''
          Which desktop shell to run.

          - `gnome`: GNOME Shell on Mutter, with GDM.
          - `dms`: DankMaterialShell on niri, with the DMS greeter.
          - `noctalia`: Noctalia on niri, with the Noctalia greeter.

          All three share the same GNOME core apps and services; only the
          shell, compositor and greeter differ. `dms` is the default until
          Noctalia v5 reaches a stable release in nixpkgs — the packaged
          version is currently a v5 beta.
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
