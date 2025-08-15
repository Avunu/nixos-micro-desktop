{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    microdesktop = {
      url = "github:Avunu/nixos-micro-desktop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

 outputs = { self, nixpkgs, microdesktop }:
  let
    hostName = "nixos"; # Replace with desired hostname
  in
  {
    nixosConfigurations = {
      "${hostName}" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          { nix.nixPath = [ "nixpkgs=${self.inputs.nixpkgs}" ]; }
          microdesktop.nixosModules.microDesktop
          ./hardware-configuration.nix
          ({ config, lib, pkgs, ... }: {
            disko.devices.disk.main.device = "/dev/sda"; # Replace with your disk device

            networking.hostName = "${hostName}";

            time.timeZone = "America/New_York"; # Replace with your timezone

            i18n.defaultLocale = "en_US.UTF-8"; # Replace with your locale

            users.users.nixos = { # Replace 'nixos' with desired username
              extraGroups = [ "wheel" "networkmanager" ];
              home.stateVersion = "25.11";
              initialPassword = "password"; # Replace with a secure password
              isNormalUser = true;
            };

            environment.systemPackages = with pkgs; [
              # Add any non-flatpak software you want on this particular machine
              # for example, insync:
              # insync
              # insync-emblem-icons
              # insync-nautilus
            ];

            services.openssh = {
              enable = true;
              settings = {
                PermitRootLogin = "yes";
                PasswordAuthentication = true;
              };
            };

            system.stateVersion = "25.11";
          })
        ];
      };
    };
  };
}
