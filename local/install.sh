nix run github:nix-community/nixos-anywhere -- --flake .#<configuration name> --target-host root@<ip address> --generate-hardware-config nixos-generate-config ./hardware-configuration.nix
