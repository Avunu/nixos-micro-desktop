{
  imports = [
    ./options.nix
    ./system/boot.nix
    ./system/hardware.nix
    ./system/memory.nix
    ./system/network.nix
    ./system/nix.nix
    ./system/storage.nix
    ./system/users.nix
    ./desktop/common.nix
    ./desktop/input-method.nix
    # One compositor/shell pair activates on microDesktop.desktopShell:
    # gnome.nix (GNOME), niri.nix + dms.nix (DankMaterialShell on niri), or
    # umbriel.nix + noctalia.nix (Noctalia on umbriel).
    ./desktop/gnome.nix
    ./desktop/niri.nix
    ./desktop/dms.nix
    ./desktop/umbriel.nix
    ./desktop/noctalia.nix
  ];
}
