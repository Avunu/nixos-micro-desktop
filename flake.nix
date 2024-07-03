{
  description = "NixOS Micro Desktop";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    nixosModules.microDesktop = { config, lib, pkgs, ... }: with lib; {
      boot = {
        kernelPackages = mkDefault pkgs.linuxPackages_latest;
        loader = {
          efi.canTouchEfiVariables = mkDefault true;
          systemd-boot.configurationLimit = mkDefault 10;
        };
        plymouth.enable = mkDefault true;
      };

      hardware = {
        bluetooth.enable = mkDefault true;
        pulseaudio.enable = mkDefault false;
        graphics = {
          enable = true;
          extraPackages = with pkgs; [
            ocl-icd
            libva1
            libva-utils
            libvdpau
            libvdpau-va-gl
            libva-vdpau-driver
            vulkan-loader
          ];
        };
        sane = {
          enable = mkDefault true;
          extraBackends = mkDefault (with pkgs; [
            hplipWithPlugin
            sane-airscan
          ]);
        };
      };

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
      };

      nix = {
        gc = {
          automatic = mkDefault true;
          dates = mkDefault "daily";
          options = mkDefault "--delete-older-than 7d";
        };
        settings.experimental-features = mkDefault [ "nix-command" "flakes" ];
      };

      programs.gnupg.agent = {
        enable = mkDefault true;
        enableSSHSupport = mkDefault true;
        pinentryPackage = mkDefault pkgs.pinentry-gnome3;
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
          interval = mkDefault "weekly";
        };

        dbus.implementation = mkDefault "broker";

        dconf.enable = mkDefault true;

        flatpak.enable = mkDefault true;

        fprintd = {
          enable = mkDefault true;
          tod.enable = mkDefault true;
        };

        fstrim = {
          enable = mkDefault true;
          interval = mkDefault "daily";
        };

        fwupd.enable = mkDefault true;

        gnome = {
          core-os-services.enable = mkDefault true;
          core-shell.enable = mkDefault true;
          core-utilities.enable = mkDefault false;
          gnome-keyring.enable = mkDefault true;
          gnome-online-accounts.enable = mkDefault true;
          gnome-remote-desktop.enable = mkDefault true;
          gnome-settings-daemon.enable = mkDefault true;
          gnome-user-share.enable = mkDefault true;
          tracker-miners.enable = mkDefault true;
          tracker.enable = mkDefault true;
        };

        gvfs.enable = mkDefault true;

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
            hplipWithPlugin
          ]);
        };

        udev.packages = with pkgs; [ gnome.gnome-settings-daemon ];

        upower.enable = mkDefault true;

        xserver = {
          enable = mkDefault true;
          displayManager.gdm.enable = mkDefault true;
        };

      };

      security = {
        polkit.enable = mkDefault true;
        tpm2.enable = mkDefault true;
      };

      xdg = {
        mime.enable = mkDefault true;
        icons.enable = mkDefault true;
        portal = {
          configPackages = mkDefault [ pkgs.gnome.gnome-session ];
          enable = mkDefault true;
          extraPortals = [
            pkgs.xdg-desktop-portal-gnome
            (pkgs.xdg-desktop-portal-gtk.override {
              buildPortalsInGnome = false;
            })
          ];
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
        liberation_ttf
        noto-fonts
        noto-fonts-cjk
        noto-fonts-emoji
        open-sans
        roboto
        roboto-mono
        roboto-serif
        roboto-slab
        source-code-pro
        source-sans-pro
        source-serif-pro
      ]);

      environment = {
        systemPackages = with pkgs; lib.flatten [
          (with gnome; [
            adwaita-icon-theme
            gnome-control-center
            gnome-shell
            gnome-themes-extra
            networkmanager-l2tp
            networkmanager-openconnect
            networkmanager-openvpn
            networkmanager-vpnc
          ])
          [
            dnsmasq
            gcr_4
            gst_all_1.gst-libav
            gst_all_1.gst-plugins-bad
            gst_all_1.gst-plugins-base
            gst_all_1.gst-plugins-good
            gst_all_1.gst-plugins-ugly
            gst_all_1.gst-vaapi
            gst_all_1.gstreamer
          ]
        ];
        sessionVariables = {
          SSH_ASKPASS_REQUIRE = "prefer";
          NIXOS_OZONE_WL = "1";
        };
        variables = {
          CLUTTER_BACKEND = "wayland";
          EGL_PLATFORM = "wayland";
          ELECTRON_OZONE_PLATFORM_HINT = "wayland";
          GDK_BACKEND = "wayland";
          GDK_PLATFORM = "wayland";
          GTK_BACKEND = "wayland";
          MOZ_ENABLE_WAYLAND = "1";
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
          "-L"
        ];
      };

      zramSwap.enable = mkDefault true;
    };
  };
}
