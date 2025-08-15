{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    microdesktop = {
      url = "github:Avunu/nixos-micro-desktop";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

 outputs = { self, nixpkgs, home-manager, microdesktop }:
  let
    # Configuration variables
    hostName = "nixos"; # Replace with desired hostname
    diskDevice = "/dev/sda"; # Replace with your disk device
    timeZone = "America/New_York"; # Replace with your timezone
    locale = "en_US.UTF-8"; # Replace with your locale
    username = "nixos"; # Replace with desired username
    initialPassword = "password"; # Replace with a secure password
    stateVersion = "25.11"; # NixOS state version
    extraPackages = with nixpkgs.legacyPackages.x86_64-linux; [
      # Add any non-flatpak software you want on this particular machine
      # for example, insync:
      # insync
      # insync-emblem-icons
      # insync-nautilus
    ];
  in
  {
    nixosConfigurations = {
      "${hostName}" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          { nix.nixPath = [ "nixpkgs=${self.inputs.nixpkgs}" ]; }
          home-manager.nixosModules.home-manager
          microdesktop.nixosModules.microDesktop
          ./hardware-configuration.nix
          ({ config, lib, pkgs, ... }: {
            disko.devices.disk.main.device = diskDevice;

            networking.hostName = hostName;

            time.timeZone = timeZone;

            i18n.defaultLocale = locale;

            users.users.${username} = { pkgs, ... }: {
              extraGroups = [ "wheel" "networkmanager" ];
              initialPassword = initialPassword;
              isNormalUser = true;
            };

            environment.systemPackages = extraPackages;

            home-manager.users.${username} = { config, pkgs, ... }: {
              home.username = username;
              home.homeDirectory = "/home/${username}";
              home.stateVersion = stateVersion;
              home.packages = extraPackages;
              programs.home-manager.enable = true;
            };

            services.openssh = {
              enable = true;
              settings = {
                PermitRootLogin = "yes";
                PasswordAuthentication = true;
              };
            };

            system.stateVersion = stateVersion;
          })
        ];
      };
    };
  };
}