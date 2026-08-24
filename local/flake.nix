{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    microdesktop = {
      url = "github:Avunu/nixos-micro-desktop";
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
      hostName = "kevin-dev-laptop";
      username = "batonac";
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
                diskDevice = "/dev/sda";
                bootMode = "uefi"; # Options: "uefi" or "legacy"
                # Root filesystem. "f2fs" is the current default; "btrfs" is
                # where this module is going and is the better pick on a new
                # install. Install-time only — it reformats nothing.
                rootFilesystem = "f2fs"; # Options: "f2fs" or "btrfs"
                # zstd level for the root filesystem: 1 / 6 / 12. Safe to
                # change on an installed machine; applies from the next write.
                compressionLevel = "fast"; # Options: "fast", "balanced", "max"
                # Disk swap partition, in GiB. 0 omits it (and hibernation).
                # zram sits above this, so it is only reached under real
                # pressure. Size it at least as large as RAM to hibernate.
                swapSizeGiB = 8;
                # Options: "dms" (niri + DankMaterialShell), "noctalia"
                # (niri + Noctalia), or "gnome" (GNOME Shell on Mutter).
                desktopShell = "dms";
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
