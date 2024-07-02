Utilize with:

```nix
{
  description = "Local NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    microdesktop.url = "github:Avunu/nixos-micro-desktop";
  };

  outputs = { self, nixpkgs, microdesktop }: {
    nixosConfigurations.default = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        microdesktop.nixosModules.microDesktop
        ./hardware-configuration.nix
        ({ config, lib, pkgs, ... }: {
          networking.hostName = "myhostname";  # Replace with desired hostname

          time.timeZone = "America/New_York";  # Replace with your timezone

          i18n.defaultLocale = "en_US.UTF-8";

          users.users.myuser = {  # Replace 'myuser' with desired username
            isNormalUser = true;
            extraGroups = [ "wheel" "networkmanager" "audio" "video" ];
          };

          environment.systemPackages = with pkgs; [
          ];

          system.stateVersion = "24.05";
        })
      ];
    };
  };
}
```
