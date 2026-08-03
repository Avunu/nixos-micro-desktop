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
    documentation = {
      doc = {
        enable = mkDefault false;
      };
      enable = mkDefault false;
      man = {
        enable = mkDefault false;
      };
      nixos = {
        enable = mkDefault false;
      };
    };

    environment = {
      shells = with pkgs; [
        bash
        nushell
      ];
    };

    i18n = {
      defaultLocale = cfg.locale;
    };

    programs = {
      git = {
        config = {
          safe = {
            directory = [ "/etc/nixos" ];
          };
        };
        enable = true;
      };
    };

    security = {
      pam = {
        services = {
          login = {
            enableGnomeKeyring = mkDefault true;
          };
        };
      };
      polkit = {
        enable = mkDefault true;
        enablePkexecWrapper = mkDefault true;
      };
      rtkit = {
        enable = mkDefault true;
      };
      tpm2 = {
        enable = mkDefault true;
      };
    };

    time = {
      timeZone = cfg.timeZone;
    };

    users = {
      defaultUserShell = pkgs.nushell;
      users = {
        ${cfg.username} = {
          extraGroups = [
            "input"
            "networkmanager"
            "wheel"
          ];
          initialPassword = cfg.initialPassword;
          isNormalUser = true;
          useDefaultShell = true;
        };
      };
    };
  };
}
