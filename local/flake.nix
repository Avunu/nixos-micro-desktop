{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    microdesktop = {
      url = "github:Avunu/nixos-micro-desktop/niri";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      microdesktop,
    }:
    let
      # Configuration variables
      hostName = "gideon-dev-01";
      username = "gideon";
      system = "x86_64-linux";
    in
    {
      nixosConfigurations = {
        "${hostName}" = nixpkgs.lib.nixosSystem {
          system = system;
          modules = [
            { nix.nixPath = [ "nixpkgs=${self.inputs.nixpkgs}" ]; }
            microdesktop.nixosModules.microDesktop
            # ./hardware-configuration.nix  # Uncomment after installation
            {
              microDesktop = {
                hostName = hostName;
                diskDevice = "/dev/nvme0n1";
                bootMode = "uefi"; # Options: "uefi" or "legacy"
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
                sshPasswordAuth = false;
                sshRootLogin = "prohibit-password";
              };
            }
          ];
        };
      };
    };
}
