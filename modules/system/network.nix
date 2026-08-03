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
    environment = {
      systemPackages = with pkgs; [
        dnsmasq
        # Miracast sink discovery — needs the 7236/7250 firewall holes below.
        gnome-network-displays
        wpa_supplicant
        wsdd
      ];
    };

    networking = {
      firewall = {
        allowedTCPPorts = [
          7236
          7250
        ];
        allowedUDPPorts = [
          7236
          5353
        ];
        enable = mkDefault false;
      };
      hostName = cfg.hostName;
      networkmanager = {
        enable = mkDefault true;
        plugins = mkIf cfg.enableVpn (
          with pkgs;
          [
            networkmanager-openvpn
            networkmanager-vpnc
            networkmanager-openconnect
            networkmanager-l2tp
          ]
        );
      };
    };

    services = {
      avahi = {
        enable = mkDefault true;
        nssmdns4 = mkDefault true;
        nssmdns6 = mkDefault true;
        publish = {
          addresses = mkDefault true;
          enable = mkDefault true;
          workstation = mkDefault true;
        };
      };
      openssh = mkIf cfg.enableSsh {
        enable = true;
        settings = {
          PasswordAuthentication = cfg.sshPasswordAuth;
          PermitRootLogin = cfg.sshRootLogin;
        };
      };
      printing = {
        browsed = {
          enable = mkDefault true;
        };
        enable = mkDefault true;
        webInterface = mkDefault false;
      };
      samba-wsdd = {
        discovery = mkDefault true;
      };
      system-config-printer = {
        enable = mkDefault true;
      };
    };

    systemd = {
      services = {
        cups-browsed-resume = {
          after = [
            "suspend.target"
            "hibernate.target"
            "hybrid-sleep.target"
          ];
          description = "Restart cups-browsed after resume from suspend";
          serviceConfig = {
            ExecStart = "systemctl restart cups-browsed";
            Type = "oneshot";
          };
          wantedBy = [
            "suspend.target"
            "hibernate.target"
            "hybrid-sleep.target"
          ];
        };
      };
    };
  };
}
