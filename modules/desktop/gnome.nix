{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.microDesktop;
in
{
  # GNOME Shell on Mutter, assembled by hand rather than via
  # services.desktopManager.gnome.enable.
  #
  # That module's core-apps set (epiphany, gnome-text-editor, gnome-calculator,
  # gnome-calendar, gnome-characters, gnome-clocks, gnome-console,
  # gnome-contacts, baobab, …) and much of core-shell (gnome-tour,
  # gnome-user-docs, gnome-backgrounds, orca, rygel, gnome-user-share,
  # gnome-remote-desktop, gnome-initial-setup) are exactly what a micro desktop
  # is not. It also forces i18n.inputMethod.type to ibus, which would fight the
  # fcitx5 pickers in desktop/input-method.nix.
  #
  # The GNOME *services* this desktop wants — keyring, GOA, settings-daemon,
  # gvfs, tinysparql, localsearch, sushi, glib-networking — are already enabled
  # unconditionally in desktop/common.nix and shared with the niri shells. All
  # that is left here is the session itself.
  config = mkIf (cfg.desktopShell == "gnome") {
    environment = {
      systemPackages = with pkgs; [
        gnome-control-center
        gnome-shell
        gnome-shell-extensions
        gnomeExtensions.appindicator
        gtk3.out # for gtk-launch
      ];
      variables = {
        XDG_CURRENT_DESKTOP = "GNOME";
        XDG_SESSION_DESKTOP = "gnome";
      };
    };

    programs = {
      dconf = {
        # Without home-manager there is no per-user extension list, so enable
        # the tray-icon extension system-wide. Users can still toggle it off.
        profiles = {
          user = {
            databases = [
              {
                settings = {
                  "org/gnome/shell" = {
                    enabled-extensions = [ pkgs.gnomeExtensions.appindicator.extensionUuid ];
                  };
                };
              }
            ];
          };
        };
      };
    };

    services = {
      displayManager = {
        defaultSession = "gnome";
        gdm = {
          enable = true;
        };
        sessionPackages = [ pkgs.gnome-session.sessions ];
      };
      geoclue2 = {
        # Night Light and automatic timezone; GNOME ships its own agent.
        appConfig = {
          gnome-color-panel = {
            isAllowed = true;
            isSystem = true;
          };
          gnome-datetime-panel = {
            isAllowed = true;
            isSystem = true;
          };
          "org.gnome.Shell" = {
            isAllowed = true;
            isSystem = true;
          };
        };
        enable = mkDefault true;
        enableDemoAgent = false;
      };
      gnome = {
        # gnome-shell needs the accessibility bus even with a11y off.
        at-spi2-core = {
          enable = mkDefault true;
        };
        # Backs the Shell's calendar/notifications and GNOME Online Accounts.
        evolution-data-server = {
          enable = mkDefault true;
        };
      };
      udev = {
        # Force enable KMS modifiers for devices that require them.
        packages = with pkgs; [ mutter ];
      };
      xserver = {
        # Export WAYLAND_DISPLAY/XDG_CURRENT_DESKTOP into the D-Bus activation
        # environment at session start, so activated services agree with the
        # session about which desktop they are running under.
        updateDbusEnvironment = true;
      };
    };

    systemd = {
      # gnome-session and gnome-shell are registered by the gdm module itself.
      user = {
        services = {
          # Same OOM reasoning as niri (see desktop/niri.nix and
          # system/memory.nix): the compositor must sort below applications,
          # which sit at +300. Applied to the template so every instance
          # (@wayland, @x11) inherits it.
          # CPUWeight/IOWeight/MemoryLow mirror the niri drop-in in
          # desktop/niri.nix: they raise the shell's share of CPU and disk
          # above the reduced share system/nix.nix gives nix-daemon and the
          # hourly rebuild, so a rebuild cannot stall a repaint. MemoryLow
          # rather than MemoryMin, so a memory squeeze slows the shell instead
          # of killing something else.
          "org.gnome.Shell@" = {
            overrideStrategy = "asDropin";
            serviceConfig = {
              CPUWeight = 200;
              IOWeight = 200;
              ManagedOOMPreference = "omit";
              MemoryLow = "512M";
              OOMScoreAdjust = -900;
            };
          };
        };
      };
    };

    xdg = {
      portal = {
        # gnome-session ships gnome-portals.conf, which takes precedence over
        # the common fallback in desktop/common.nix when XDG_CURRENT_DESKTOP
        # is GNOME.
        configPackages = with pkgs; [ gnome-session ];
      };
    };
  };
}
