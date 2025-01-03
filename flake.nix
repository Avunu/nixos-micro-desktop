{
  description = "NixOS Micro Desktop";

  inputs = {

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-flatpak.url = "github:gmodena/nix-flatpak";

  };

  outputs = inputs@{ self, nixpkgs, nix-flatpak, ... }: {
    nixosModules.microDesktop = { config, lib, pkgs, ... }: with lib; {
      boot = {
        initrd.kernelModules = mkDefault [ "fbcon" ];
        kernelPackages = mkDefault pkgs.linuxPackages_latest;
        kernelParams = mkDefault [
          "boot.shell_on_fail"
          "console=tty0"
          "fbcon=vc:2-6"
          "i915.enable_guc=3"
          "i915.modeset=1"
          "loglevel=3"
          "mem_sleep_default=deep"
          "pcie_aspm.policy=powersupersave"
          "quiet"
          "rd.systemd.show_status=false"
          "rd.udev.log_level=3"
          "splash"
          "udev.log_priority=3"
        ];
        consoleLogLevel = mkDefault 0;
        initrd = {
          systemd = {
            enable = mkDefault true;
            tpm2.enable = mkDefault true;
          };
          verbose = mkDefault false;
        };
        loader = {
          efi.canTouchEfiVariables = mkDefault true;
          systemd-boot = {
            configurationLimit = mkDefault 10;
            enable = mkDefault true;
          };
        };
        plymouth.enable = mkDefault true;
      };

      console = {
        keyMap = mkDefault "us";
        packages = mkDefault [
            pkgs.terminus_font
        ];
      };

      documentation = {
        enable = mkDefault false;
        doc.enable = mkDefault false;
        man.enable = mkDefault false;
        nixos.enable = mkDefault false;
      };

      environment = {
        pathsToLink = [
          "/share" # TODO: https://github.com/NixOS/nixpkgs/issues/47173
        ];
        systemPackages = with pkgs; lib.flatten [
          (with gnome; [
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
            fcitx5
            gcr_4
            glib
            gnome-backgrounds
            gnome-console
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
            podman-compose
            sushi
            uutils-coreutils-noprefix
            wpa_supplicant
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
          GTK_IM_MODULE = "wayland";
          LD_LIBRARY_PATH = lib.mkForce "/etc/sane-libs/:/run/opengl-driver/lib";
          MOZ_ENABLE_WAYLAND = "1";
          NIX_GSETTINGS_OVERRIDES_DIR = "${pkgs.gnome.nixos-gsettings-overrides}/share/gsettings-schemas/nixos-gsettings-overrides/glib-2.0/schemas";
          NIXOS_OZONE_WL = "1";
          OCL_ICD_VENDORS = "/run/opengl-driver/etc/OpenCL/vendors";
          PROTOC = "${pkgs.protobuf}/bin/protoc";
          QML_DISABLE_DISK_CACHE = "1";
          QT_IM_MODULE = "wayland";
          QT_QPA_PLATFORM = "wayland";
          QT_SCALE_FACTOR_ROUNDING_POLICY = "RoundPreferFloor";
          SDL_VIDEODRIVER = "wayland";
          XDG_SESSION_TYPE = "wayland";
          XMODIFIERS = "@im=fcitx";
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
        meslo-lgs-nf
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

      i18n.inputMethod = {
        type = mkDefault "fcitx5";
        fcitx5 = {
          addons = with pkgs; [
            fcitx5-configtool
            fcitx5-gtk
            catppuccin-fcitx5
          ];
          settings.addons = mkDefault { pinyin.globalSection.EmojiEnabled = "True"; };
          waylandFrontend = mkDefault true;
        };
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
          wifi.backend = mkDefault "wpa_supplicant";
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

        git = {
          config.safe.directory = [ "/etc/nixos" ];
          enable = true;
        };

        gnupg.agent = {
          enable = mkDefault true;
          enableSSHSupport = mkDefault true;
          pinentryPackage = mkDefault pkgs.pinentry-gnome3;
        };

        nix-ld = {
          enable = mkDefault true;
          libraries = with pkgs; [
            alsa-lib
            glib
            json-glib
            libxkbcommon
            openssl
            vulkan-loader
            vulkan-validation-layers
            wayland
            zstd
          ];
          package = pkgs.nix-ld-rs;
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
            "io.missioncenter.MissionCenter"
            "org.freedesktop.Platform.ffmpeg-full/x86_64/24.08"
            "org.freedesktop.Platform.GStreamer.gstreamer-vaapi/x86_64/23.08"
            "org.gnome.Loupe"
            "org.gnome.Papers"
            "org.gnome.Platform/x86_64/47"
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
          localsearch.enable = mkForce false;
          rygel.enable = mkDefault true;
          tinysparql.enable = mkDefault true;
        };

        # greetd.vt = mkDefault 2;

        gvfs.enable = mkDefault true;

        kmscon = {
          enable = true;
          hwRender = true;
        };

        libinput.enable = mkDefault true;

        power-profiles-daemon.enable = mkDefault true;

        pipewire = {
          enable = mkDefault true;
          alsa.enable = mkDefault true;
          pulse.enable = mkDefault true;
          wireplumber = {
            enable = true;
            extraConfig = {
              "10-bluez" = {
                "monitor.bluez.properties" = {
                  "bluez5.enable-sbc-xq" = true;
                  "bluez5.enable-msbc" = true;
                  "bluez5.enable-hw-volume" = true;
                  "bluez5.codecs" = ["sbc" "sbc_xq" "aac" "ldac" "aptx" "aptx_hd"];
                };
              };
            };
          };
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

      systemd = {
        packages = with pkgs; [
          gnome-session
          gnome-shell
        ];
        services = {
          flake-update = {
            unitConfig = {
              Description = "Update flake inputs";
              StartLimitIntervalSec = 300;
              StartLimitBurst = 5;
            };
            serviceConfig = {
              ExecStart = "${pkgs.nix}/bin/nix flake update --commit-lock-file --flake /etc/nixos";
              Restart = "no";
              Type = "oneshot";
              User = "root";
              Environment = "HOME=/root";
            };
            before = ["nixos-upgrade.service"];
            after = ["network-online.target"];
            wants = ["network-online.target"];
            path = [pkgs.nix pkgs.git pkgs.host];
            requiredBy = ["nixos-upgrade.service"];
          };
        };
      };

      virtualisation.podman = {
        defaultNetwork.settings.dns_enabled = true;
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

      system.autoUpgrade = {
        allowReboot = mkDefault false;
        enable = mkDefault true;
        flake = mkDefault "/etc/nixos";
        # flags = mkDefault [
        #   "--recreate-lock-file"
        #   "--update-input" "nixpkgs"
        #   "--update-input" "microdesktop"
        # ];
      };

      users.defaultUserShell = pkgs.bashInteractive;

      zramSwap.enable = mkDefault true;
    };
  };
}
