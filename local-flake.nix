{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    microdesktop = {
      url = "github:Avunu/nixos-micro-desktop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, microdesktop }: {
    nixosConfigurations = {
      "${nixos-hostname}" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          microdesktop.nixosModules.microDesktop
          ./hardware-configuration.nix
          ({ config, lib, pkgs, ... }: {
            networking.hostName = "myhostname"; # Replace with desired hostname

            time.timeZone = "America/New_York"; # Replace with your timezone

            i18n.defaultLocale = "en_US.UTF-8"; # Replace with your locale

            users.users.myuser = {
              # Replace 'myuser' with desired username
              isNormalUser = true;
              extraGroups = [ "wheel" "networkmanager" ];
            };

            environment.systemPackages = with pkgs; [
              # Add any non-flatpak software you want on this particular machine
              # for example, insync:
              insync
              insync-emblem-icons
              insync-nautilus
            ];

            system.stateVersion = "24.05";
          })
        ];
      };
    };
  };
}
