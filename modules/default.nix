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
    # One of these three activates on microDesktop.desktopShell; niri.nix is
    # shared by dms and noctalia.
    ./desktop/gnome.nix
    ./desktop/niri.nix
    ./desktop/dms.nix
    ./desktop/noctalia.nix
  ];
}
