{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    microdesktop = {
      url = "github:Avunu/nixos-micro-desktop/niri";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      microdesktop,
    }:
    let
      # Configuration variables
      hostName = "nixos";
      username = "nixos";
      system = "x86_64-linux";
    in
    {
      nixosConfigurations = {
        "${hostName}" = nixpkgs.lib.nixosSystem {
          system = system;
          modules = [
            { nix.nixPath = [ "nixpkgs=${self.inputs.nixpkgs}" ]; }
            microdesktop.nixosModules.microDesktop
            {
              microDesktop = {
                hostName = hostName;
                diskDevice = "/dev/sda";
                timeZone = "America/New_York";
                locale = "en_US.UTF-8";
                username = username;
                initialPassword = "password";
                stateVersion = "25.11";
                extraPackages = with nixpkgs.legacyPackages.${system}; [
                  # Add any non-flatpak software you want on this particular machine
                  # for example, insync:
                  # insync
                  # insync-emblem-icons
                  # insync-nautilus
                ];
                enableSsh = true;
                sshPasswordAuth = true;
                sshRootLogin = "yes";
              };
            }
          ];
        };
      };
    };
}