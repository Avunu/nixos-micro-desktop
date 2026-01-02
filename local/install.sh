#!/usr/bin/env bash
# Usage: ./install.sh <ip-address>
# Example: ./install.sh 192.168.1.100
#
# Before running, configure your settings in flake.nix:
#   - hostName
#   - username
#   - diskDevice
#   - bootMode (uefi or legacy)
#   - timeZone
#   - locale
#   - and other options as needed

if [ -z "$1" ]; then
  echo "Usage: $0 <ip-address>"
  echo "Example: $0 192.168.1.100"
  exit 1
fi

TARGET_HOST="root@$1"
CONFIG_NAME=$(nix eval --raw .#nixosConfigurations --apply 'x: builtins.head (builtins.attrNames x)')

echo "Installing NixOS configuration '$CONFIG_NAME' to $TARGET_HOST..."
nix run github:nix-community/nixos-anywhere -- --flake .#"$CONFIG_NAME" --target-host "$TARGET_HOST"