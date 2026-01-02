#!/usr/bin/env bash
set -euo pipefail

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

IP_ADDRESS="$1"
TARGET_HOST="root@${IP_ADDRESS}"
CONFIG_NAME=$(nix eval --raw .#nixosConfigurations --apply 'x: builtins.head (builtins.attrNames x)')

echo "🚀 Installing NixOS Micro Desktop configuration '${CONFIG_NAME}' to ${TARGET_HOST}..."
echo ""

# Create a temporary directory for flake
temp=$(mktemp -d)

# Function to cleanup temporary directory on exit
cleanup() {
  rm -rf "$temp"
}
trap cleanup EXIT

echo "📋 Copying flake configuration to ${temp}/etc/nixos/..."
# Copy the local flake.nix to /etc/nixos/ on the target system
mkdir -p "${temp}/etc/nixos"
cp flake.nix "${temp}/etc/nixos/flake.nix"
chmod 644 "${temp}/etc/nixos/flake.nix"

echo "🔧 Running nixos-anywhere..."
# Install NixOS to the host system with our flake
nix run github:nix-community/nixos-anywhere -- \
  --extra-files "$temp" \
  --flake ".#${CONFIG_NAME}" \
  --target-host "$TARGET_HOST"

echo ""
echo "✅ Installation complete!"
echo ""
echo "The system is now running with:"
echo "  - Flake configuration in /etc/nixos"
echo "  - Auto-update enabled for /etc/nixos flake"
echo ""
echo "To access the system:"
echo "  ssh ${CONFIG_NAME} (if mDNS is working)"
echo "  ssh root@${IP_ADDRESS}"
echo ""
echo "To update the system:"
echo "  ssh root@${IP_ADDRESS} 'cd /etc/nixos && nix flake update && nixos-rebuild switch --flake .'"