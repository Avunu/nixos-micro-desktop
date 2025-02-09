{
  description = "NixOS Micro Desktop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-software-center = {
      url = "github:batonac/nix-software-center";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-software-center,
      ...
    }:
    let
      lib = nixpkgs.lib;
    in
    {
      nixosModules.microDesktop =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        with lib;
        {
          boot.initrd.kernelModules = mkDefault [ "fbcon" ];
          boot.kernelPackages = mkDefault pkgs.linuxPackages_latest;
          boot.kernelParams = mkDefault [
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
          boot.consoleLogLevel = mkDefault 0;
          boot.initrd.systemd.enable = mkDefault true;
          boot.initrd.systemd.tpm2.enable = mkDefault true;
          boot.initrd.verbose = mkDefault false;
          boot.loader.efi.canTouchEfiVariables = mkDefault true;
          boot.loader.systemd-boot.configurationLimit = mkDefault 10;
          boot.loader.systemd-boot.enable = mkDefault true;
          boot.plymouth.enable = mkDefault true;

          console.keyMap = mkDefault "us";
          console.packages = mkDefault [
            pkgs.terminus_font
          ];

          documentation.enable = mkDefault false;
          documentation.doc.enable = mkDefault false;
          documentation.man.enable = mkDefault false;
          documentation.nixos.enable = mkDefault false;

          environment.pathsToLink = [
            "/share" # TODO: https://github.com/NixOS/nixpkgs/issues/47173
          ];
          environment.sessionVariables = {
            CLUTTER_BACKEND = "wayland";
            EGL_PLATFORM = "wayland";
            ELECTRON_OZONE_PLATFORM_HINT = "wayland";
            GDK_BACKEND = "wayland";
            GDK_PLATFORM = "wayland";
            GTK_BACKEND = "wayland";
            GTK_IM_MODULE = "wayland";
            LD_LIBRARY_PATH = mkForce "/etc/sane-libs/:/run/opengl-driver/lib";
            MOZ_ENABLE_WAYLAND = "1";
            NIX_GSETTINGS_OVERRIDES_DIR = "${pkgs.gnome.nixos-gsettings-overrides}/share/gsettings-schemas/nixos-gsettings-overrides/glib-2.0/schemas";
            NIXOS_OZONE_WL = "1";
            NIXPKGS_ALLOW_UNFREE = "1";
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

          fonts.packages = mkDefault (
            with pkgs;
            [
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
            ]
          );

          hardware.bluetooth.enable = mkDefault true;
          hardware.enableRedistributableFirmware = mkDefault true;
          hardware.graphics.enable = true;
          hardware.graphics.extraPackages = with pkgs; [
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
          hardware.sane.enable = mkDefault true;
          hardware.sane.extraBackends = mkDefault (
            with pkgs;
            [
              sane-airscan
            ]
          );
          hardware.sensor.iio.enable = mkDefault true;

          i18n.inputMethod.type = mkDefault "fcitx5";
          i18n.inputMethod.fcitx5.addons = with pkgs; [
            fcitx5-configtool
            fcitx5-gtk
            catppuccin-fcitx5
          ];
          i18n.inputMethod.fcitx5.settings.addons = mkDefault { pinyin.globalSection.EmojiEnabled = "True"; };
          i18n.inputMethod.fcitx5.waylandFrontend = mkDefault true;

          networking.networkmanager.enable = mkDefault true;
          networking.networkmanager.plugins = mkDefault (
            with pkgs;
            [
              networkmanager-openvpn
              networkmanager-vpnc
              networkmanager-openconnect
              networkmanager-l2tp
            ]
          );
          networking.networkmanager.wifi.backend = mkDefault "wpa_supplicant";
          networking.firewall.enable = mkDefault false;
          networking.firewall.allowedTCPPorts = [
            7236
            7250
          ];
          networking.firewall.allowedUDPPorts = [
            7236
            5353
          ];

          nix.gc.automatic = mkDefault true;
          nix.gc.dates = mkDefault "weekly";
          nix.gc.options = mkDefault "--delete-older-than 7d";
          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];
          nix.settings.substituters = [
            "https://cache.nixos.org?priority=40"
            "https://nix-community.cachix.org?priority=41"
          ];
          nix.settings.trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          ];
          nix.settings.trusted-users = [
            "root"
            "nixos"
            "@wheel"
          ];

          nixpkgs.config.allowUnfree = mkDefault true;

          programs.dconf.enable = mkDefault true;
          programs.git.config.safe.directory = [ "/etc/nixos" ];
          programs.git.enable = true;
          programs.gnupg.agent.enable = mkDefault true;
          programs.gnupg.agent.enableSSHSupport = mkDefault true;
          programs.gnupg.agent.pinentryPackage = mkDefault pkgs.pinentry-gnome3;
          programs.nix-ld.enable = mkDefault true;
          programs.nix-ld.libraries = with pkgs; [
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
          programs.nix-ld.package = pkgs.nix-ld-rs;
          programs.regreet.enable = mkDefault true;
          programs.regreet.settings = {
            GTK.application_prefer_dark_theme = mkDefault true;
          };

          services.accounts-daemon.enable = mkDefault true;
          services.avahi.enable = mkDefault true;
          services.avahi.nssmdns4 = mkDefault true;
          services.avahi.publish.addresses = mkDefault true;
          services.avahi.publish.enable = mkDefault true;
          services.avahi.publish.workstation = mkDefault true;
          services.btrfs.autoScrub.enable = mkDefault true;
          services.btrfs.autoScrub.fileSystems = mkDefault [ "/" ];
          services.btrfs.autoScrub.interval = mkDefault "daily";
          services.colord.enable = mkDefault true;
          services.dbus.implementation = mkDefault "broker";
          services.dbus.packages = with pkgs; [
            gcr
            gnome-keyring
          ];
          services.displayManager.defaultSession = "gnome";
          services.displayManager.sessionPackages = [ pkgs.gnome-session.sessions ];
          services.fstrim.enable = mkDefault true;
          services.fstrim.interval = mkDefault "daily";
          services.fwupd.enable = mkDefault true;
          services.gnome.glib-networking.enable = mkDefault true;
          services.gnome.gnome-browser-connector.enable = mkForce false;
          services.gnome.gnome-keyring.enable = mkDefault true;
          services.gnome.gnome-online-accounts.enable = mkDefault true;
          services.gnome.gnome-remote-desktop.enable = mkDefault false;
          services.gnome.gnome-settings-daemon.enable = mkDefault true;
          services.gnome.gnome-user-share.enable = mkDefault false;
          services.gnome.localsearch.enable = mkForce false;
          services.gnome.rygel.enable = mkDefault true;
          services.gnome.tinysparql.enable = mkDefault true;
          services.gvfs.enable = mkDefault true;
          services.kmscon.enable = true;
          services.kmscon.hwRender = true;
          services.libinput.enable = mkDefault true;
          services.power-profiles-daemon.enable = mkDefault true;
          services.pipewire.enable = mkDefault true;
          services.pipewire.alsa.enable = mkDefault true;
          services.pipewire.pulse.enable = mkDefault true;
          services.pipewire.wireplumber.enable = true;
          services.pipewire.wireplumber.extraConfig = {
            "10-bluez" = {
              "monitor.bluez.properties" = {
                "bluez5.enable-sbc-xq" = true;
                "bluez5.enable-msbc" = true;
                "bluez5.enable-hw-volume" = true;
                "bluez5.codecs" = [
                  "sbc"
                  "sbc_xq"
                  "aac"
                  "ldac"
                  "aptx"
                  "aptx_hd"
                ];
              };
            };
          };
          services.printing.enable = mkDefault true;
          services.printing.drivers = mkDefault (
            with pkgs;
            [
              gutenprint
            ]
          );
          services.printing.webInterface = mkDefault false;
          services.system-config-printer.enable = mkDefault true;
          services.udev.packages = with pkgs; [
            gnome-settings-daemon
            mutter
          ];
          services.udisks2.enable = true;
          services.upower.enable = mkDefault true;

          security.pam.services.login.enableGnomeKeyring = mkDefault true;
          security.polkit.enable = mkDefault true;
          security.rtkit.enable = mkDefault true;
          security.tpm2.enable = mkDefault true;

          systemd.packages = with pkgs; [
            gnome-session
            gnome-shell
          ];
          systemd.services.flake-update.unitConfig = {
            Description = "Update flake inputs";
            StartLimitIntervalSec = 300;
            StartLimitBurst = 5;
          };
          systemd.services.flake-update.serviceConfig = {
            ExecStart = "${pkgs.nix}/bin/nix flake update --commit-lock-file --flake /etc/nixos";
            Restart = "on-failure";
            RestartSec = "120s";
            Type = "oneshot";
            User = "root";
            Environment = "HOME=/root";
          };
          systemd.services.flake-update.wants = [ "network-online.target" ];
          systemd.services.flake-update.after = [ "network-online.target" ];
          systemd.services.flake-update.before = [ "nixos-upgrade.service" ];
          systemd.services.flake-update.path = with pkgs; [
            nix
            git
            host
          ];
          systemd.services.flake-update.requiredBy = [ "nixos-upgrade.service" ];

          virtualisation.podman.defaultNetwork.settings.dns_enabled = true;
          virtualisation.podman.dockerCompat = mkDefault true;
          virtualisation.podman.dockerSocket.enable = mkDefault true;
          virtualisation.podman.enable = mkDefault true;

          xdg.mime.enable = mkDefault true;
          xdg.icons.enable = mkDefault true;
          xdg.portal.configPackages = mkDefault [ pkgs.gnome-session ];
          xdg.portal.enable = mkDefault true;
          xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
          xdg.portal.xdgOpenUsePortal = mkDefault true;

          system.autoUpgrade.allowReboot = mkDefault false;
          system.autoUpgrade.enable = mkDefault true;
          system.autoUpgrade.flake = mkDefault "/etc/nixos";

          users.defaultUserShell = pkgs.bashInteractive;

          zramSwap.enable = mkDefault true;

          environment.systemPackages =
            with pkgs;
            lib.flatten [
              (with gnome; [ nixos-gsettings-overrides ])
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
                nix-software-center.packages.${pkgs.system}.nix-software-center
                podman-compose
                sushi
                uutils-coreutils-noprefix
                wpa_supplicant
                xdg-user-dirs
              ]
            ];
        };
    };
}
