# NixOS Micro Desktop

NixOS Micro Desktop is an OpenSUSE Aeon-inspired desktop, but powered by NixOS. The goals is to create a NixOS configuration that's suitable for "family and friends". In other words, if you really care about declarative systems, you probably want to use Nix directly to install and configure your computer. Micro Desktop, in contrast, provides the goodness of a minimal but functional system that can be configured using Gnome settings and software, without worring with about the underlying system.

## Features

- Latest kernel for optimal hardware support
- GNOME desktop environment with essential applications
- Network Manager with VPN support
- Flatpak integration for easy application management
- Optimized audio setup with PipeWire
- Printer and scanner support out of the box
- Automatic system maintenance (TRIM, BTRFS scrubbing)
- And much more!

## Installation

Follow these steps to install NixOS Micro Desktop:

1. **Install NixOS with BTRFS root**
   - Download the latest NixOS ISO
   - During installation, ensure you set up your root partition as BTRFS

2. **Download and customize the sample flake**
   - Once your system is up and running, download the sample flake to `/etc/nixos/`:
     ```
     sudo curl -o /etc/nixos/flake.nix https://raw.githubusercontent.com/Avunu/nixos-micro-desktop/main/local-flake.nix
     ```
   - Customize the flake according to your needs:
     ```
     sudo nano /etc/nixos/flake.nix
     ```
   - Update the flake:
     ```
     sudo nix flake update /etc/nixos --extra-experimental-features nix-command flakes
     ```

3. **Delete the old configuration.nix**
   - Remove the old configuration file:
     ```
     sudo rm /etc/nixos/configuration.nix
     ```

4. **Rebuild and reboot**
   - Rebuild your system using the new flake:
     ```
     sudo nixos-rebuild switch --flake /etc/nixos#default
     ```
   - Reboot your system to apply all changes:
     ```
     sudo reboot
     ```

## Customization

The beauty of NixOS Micro Desktop lies in its customizability. Feel free to modify the flake to add or remove packages, change system settings, or tweak the GNOME environment to your liking.

## Contributing

We welcome contributions! If you have improvements or bug fixes, please open a pull request or issue on our GitHub repository.

## Support

If you need help or have questions, please open an issue on our GitHub repository or join our community chat.

Enjoy your sleek, efficient, and customizable NixOS Micro Desktop!
