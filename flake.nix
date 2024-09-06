{
  description = "NixOS Micro Desktop";

  inputs = {

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-flatpak.url = "github:gmodena/nix-flatpak";

  };

  outputs = inputs@{ self, nixpkgs, nix-flatpak, ... }: {
    nixosModules.microDesktop = { config, lib, pkgs, ... }: with lib; {
      boot = {
        kernelPackages = mkDefault pkgs.linuxPackages_latest;
        # energy savings
        kernelParams = [ "mem_sleep_default=deep" "pcie_aspm.policy=powersupersave" "quiet" "splash" "loglevel=0" ];
        loader = {
          efi.canTouchEfiVariables = mkDefault true;
          systemd-boot = {
            configurationLimit = mkDefault 10;
            enable = mkDefault true;
          };
        };
        plymouth.enable = mkDefault true;
      };

      documentation = {
        enable = mkDefault false;
        doc.enable = mkDefault false;
        man.enable = mkDefault false;
        nixos.enable = mkDefault false;
      };

      hardware = {
        bluetooth.enable = mkDefault true;
        enableRedistributableFirmware = mkDefault true;
        # opentabletdriver.enable = mkDefault true;
        pulseaudio.enable = mkDefault false;
        graphics = {
          enable = true;
          extraPackages = with pkgs; [
            intel-media-driver
            intel-vaapi-driver
            libva-utils
            libva-vdpau-driver
            libva1
            libvdpau
            libvdpau-va-gl
            nvidia-vaapi-driver
            ocl-icd
            vulkan-loader
          ];
        };
        sane = {
          enable = mkDefault true;
          extraBackends = mkDefault (with pkgs; [
            # hplip
            sane-airscan
          ]);
        };
        sensor.iio.enable = mkDefault true;
      };

      imports = [
        nix-flatpak.nixosModules.nix-flatpak
      ];

      networking = {
        networkmanager = {
          enable = mkDefault true;
          plugins = mkDefault (with pkgs; [
            networkmanager-openvpn
            networkmanager-vpnc
            networkmanager-openconnect
            networkmanager-l2tp
          ]);
        };
        firewall = {
          enable = mkDefault false;
          allowedTCPPorts = [ 7236 7250 ];
          allowedUDPPorts = [ 7236 5353 ];
        };
      };

      nix = {
        gc = {
          automatic = mkDefault true;
          dates = mkDefault "weekly";
          options = mkDefault "--delete-older-than 7d";
        };
        settings.experimental-features = mkDefault [ "nix-command" "flakes" ];
      };

      nixpkgs.config = {
        allowUnfree = mkDefault true;
      };

      programs = {

        dconf.enable = mkDefault true;

        gnupg.agent = {
          enable = mkDefault true;
          enableSSHSupport = mkDefault true;
          pinentryPackage = mkDefault pkgs.pinentry-gnome3;
        };

        nix-ld = {
          enable = mkDefault true;
          libraries = with pkgs; [ glib json-glib ];
        };

        regreet = {
          enable = mkDefault true;
          settings = {
            GTK.application_prefer_dark_theme = mkDefault true;
          };
        };

      };

      services = {

        accounts-daemon.enable = mkDefault true;

        avahi = {
          enable = mkDefault true;
          nssmdns4 = mkDefault true;
          publish = {
            addresses = mkDefault true;
            enable = mkDefault true;
            workstation = mkDefault true;
          };
        };

        btrfs.autoScrub = {
          enable = mkDefault true;
          fileSystems = mkDefault [ "/" ];
          interval = mkDefault "daily";
        };

        colord.enable = mkDefault true;

        dbus = {
          implementation = mkDefault "broker";
          packages = with pkgs; [
            gcr
            gnome-keyring
          ];
        };

        displayManager.sessionPackages = [ pkgs.gnome-session.sessions ];

        flatpak = {
          enable = mkDefault true;
          overrides = {
            global = {
              # Enable Wayland by default
              Context = {
                sockets = [ "wayland" "!fallback-x11" "!x11" ];
                filesystems = [ "/run/current-system/sw/share/X11/fonts:ro;/nix/store:ro;/run/dbus/system_bus_socket:rw" ];
              };

              Environment = {
                # Fix un-themed cursor in some Wayland apps
                XCURSOR_PATH = "/run/host/user-share/icons:/run/host/share/icons";
              };
            };

            # X11 only apps
            "com.synology.SynologyDrive".Context.sockets = [ "x11" ];
            "net.xmind.XMind".Context.sockets = [ "x11" ];
            "net.xmind.XMind8".Context.sockets = [ "x11" ];
            "org.onlyoffice.desktopeditors".Context.sockets = [ "x11" ];
            "com.logseq.Logseq".Context.sockets = [ "x11" ];

          };
          packages = mkDefault [
            "org.freedesktop.Platform.ffmpeg-full/x86_64/23.08"
            "org.freedesktop.Platform.GStreamer.gstreamer-vaapi/x86_64/23.08"
            "org.gnome.Loupe"
            "org.gnome.Papers"
            "org.gnome.Showtime"
            "org.gtk.Gtk3theme.adw-gtk3-dark"
            "org.gtk.Gtk3theme.adw-gtk3"
          ];
          update.auto = {
            enable = mkDefault true;
            onCalendar = mkDefault "daily";
          };
        };

        # fprintd = {
        #   enable = mkDefault true;
        # };

        fstrim = {
          enable = mkDefault true;
          interval = mkDefault "daily";
        };

        fwupd.enable = mkDefault true;

        gnome = {
          # core-shell.enable = mkDefault true;
          glib-networking.enable = mkDefault true;
          gnome-browser-connector.enable = mkForce false;
          gnome-keyring.enable = mkDefault true;
          gnome-online-accounts.enable = mkDefault true;
          gnome-remote-desktop.enable = mkDefault false;
          gnome-settings-daemon.enable = mkDefault true;
          gnome-user-share.enable = mkDefault false;
          rygel.enable = mkDefault true;
          tracker-miners.enable = mkForce false;
          tracker.enable = mkDefault true;
        };

        gvfs.enable = mkDefault true;

        libinput.enable = mkDefault true;

        power-profiles-daemon.enable = mkDefault true;

        pipewire = {
          enable = mkDefault true;
          alsa.enable = mkDefault true;
          pulse.enable = mkDefault true;
        };

        printing = {
          enable = mkDefault true;
          drivers = mkDefault (with pkgs; [
            gutenprint
            # hplip
          ]);
          webInterface = mkDefault false;
        };
        
        system-config-printer.enable = mkDefault true;

        udev.packages = with pkgs; [
          gnome-settings-daemon
          mutter
        ];

        udisks2.enable = true;

        upower.enable = mkDefault true;

      };

      security = {
        pam.services.login.enableGnomeKeyring = mkDefault true;
        polkit.enable = mkDefault true;
        rtkit.enable = mkDefault true;
        tpm2.enable = mkDefault true;
      };

      systemd.packages = with pkgs; [
        gnome-session
        gnome-shell
      ];

      virtualisation.podman = {
        dockerCompat = mkDefault true;
        dockerSocket.enable = mkDefault true;
        enable = mkDefault true;
      };

      xdg = {
        mime.enable = mkDefault true;
        icons.enable = mkDefault true;
        portal = {
          configPackages = mkDefault [ pkgs.gnome-session ];
          enable = mkDefault true;
          extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
          xdgOpenUsePortal = mkDefault true;
        };
      };

      fonts.packages = mkDefault (with pkgs; [
        caladea
        cantarell-fonts
        carlito
        dejavu_fonts
        fira-code
        fira-code-symbols
        fira-mono
        fira-sans
        liberation_ttf
        noto-fonts
        noto-fonts-cjk
        noto-fonts-emoji
        open-sans
        roboto
        roboto-mono
        roboto-serif
        roboto-slab
        source-code
        source-code-pro
        source-sans
        source-sans-pro
        source-serif
        source-serif-pro
      ]);

      environment = {
        pathsToLink = [
          "/share" # TODO: https://github.com/NixOS/nixpkgs/issues/47173
        ];
        systemPackages = with pkgs; lib.flatten [
          (with gnome; [
            gnome-console
            nixos-gsettings-overrides
          ])
          (with gnomeExtensions; [
            another-window-session-manager
            appindicator
          ])
          [
            adwaita-icon-theme
            distrobox
            dnsmasq
            gcr_4
            glib
            gnome-backgrounds
            gnome-control-center
            gnome-menus
            gnome-network-displays
            gnome-shell-extensions
            gnome-software
            gnome-themes-extra
            gst_all_1.gst-libav
            gst_all_1.gst-plugins-bad
            gst_all_1.gst-plugins-base
            gst_all_1.gst-plugins-good
            gst_all_1.gst-plugins-ugly
            gst_all_1.gst-vaapi
            gst_all_1.gstreamer
            gtk3.out
            nautilus
            sushi
            xdg-user-dirs
          ]
        ];
        sessionVariables = {
          CLUTTER_BACKEND = "wayland";
          EGL_PLATFORM = "wayland";
          ELECTRON_OZONE_PLATFORM_HINT = "wayland";
          GDK_BACKEND = "wayland";
          GDK_PLATFORM = "wayland";
          GTK_BACKEND = "wayland";
          MOZ_ENABLE_WAYLAND = "1";
          NIX_GSETTINGS_OVERRIDES_DIR = "${pkgs.gnome.nixos-gsettings-overrides}/share/gsettings-schemas/nixos-gsettings-overrides/glib-2.0/schemas";
          NIXOS_OZONE_WL = "1";
          OCL_ICD_VENDORS = "/run/opengl-driver/etc/OpenCL/vendors";
          QML_DISABLE_DISK_CACHE = "1";
          QT_QPA_PLATFORM = "wayland";
          QT_SCALE_FACTOR_ROUNDING_POLICY = "RoundPreferFloor";
          SDL_VIDEODRIVER = "wayland";
          XDG_SESSION_TYPE = "wayland";
        };
      };

      system.autoUpgrade = {
        allowReboot = mkDefault false;
        enable = mkDefault true;
        flake = "/etc/nixos";
        flags = mkDefault [
          "--update-input"
          "nixpkgs"
          "--update-input"
          "microdesktop"
          "-L"
        ];
      };

      zramSwap.enable = mkDefault true;
    };
  };
}
