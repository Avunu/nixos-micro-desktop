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
          boot = {
            initrd = {
              kernelModules = mkDefault [ "fbcon" ];
              systemd = {
                enable = mkDefault true;
                tpm2.enable = mkDefault true;
              };
              verbose = mkDefault false;
            };
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
            packages = mkDefault [ pkgs.terminus_font ];
          };

          documentation = {
            enable = mkDefault false;
            doc.enable = mkDefault false;
            man.enable = mkDefault false;
            nixos.enable = mkDefault false;
          };

          environment = {
            pathsToLink = [ "/share" ];
            sessionVariables = {
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
            systemPackages =
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

          hardware = {
            bluetooth.enable = mkDefault true;
            enableRedistributableFirmware = mkDefault true;
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
              extraBackends = mkDefault (with pkgs; [ sane-airscan ]);
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

          networking = {
            networkmanager = {
              enable = mkDefault true;
              plugins = mkDefault (
                with pkgs;
                [
                  networkmanager-openvpn
                  networkmanager-vpnc
                  networkmanager-openconnect
                  networkmanager-l2tp
                ]
              );
              wifi.backend = mkDefault "wpa_supplicant";
            };
            firewall = {
              enable = mkDefault false;
              allowedTCPPorts = [
                7236
                7250
              ];
              allowedUDPPorts = [
                7236
                5353
              ];
            };
          };

          nix = {
            gc = {
              automatic = mkDefault true;
              dates = mkDefault "weekly";
              options = mkDefault "--delete-older-than 7d";
            };
            settings = {
              experimental-features = [
                "nix-command"
                "flakes"
              ];
              substituters = [
                "https://cache.nixos.org?priority=40"
                "https://nix-community.cachix.org?priority=41"
              ];
              trusted-public-keys = [
                "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
                "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
              ];
              trusted-users = [
                "root"
                "nixos"
                "@wheel"
              ];
            };
          };

          nixpkgs.config.allowUnfree = mkDefault true;

          programs = {
            appimage.enable = mkDefault true;
            dconf.enable = mkDefault true;
            git = {
              enable = true;
              config.safe.directory = [ "/etc/nixos" ];
            };
            gnupg.agent = {
              enable = mkDefault true;
              enableSSHSupport = mkDefault true;
              pinentryPackage = mkDefault pkgs.pinentry-gnome3;
            };
            nix-ld = {
              enable = mkDefault true;
              package = pkgs.nix-ld-rs;
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
            };
            regreet = {
              enable = mkDefault true;
              settings.GTK.application_prefer_dark_theme = mkDefault true;
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
                dconf
                gcr
                gnome-keyring
              ];
            };
            displayManager = {
              defaultSession = "gnome";
              sessionPackages = [ pkgs.gnome-session.sessions ];
            };
            fstrim = {
              enable = mkDefault true;
              interval = mkDefault "daily";
            };
            fwupd.enable = mkDefault true;
            gnome = {
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
                extraConfig."10-bluez".monitor.bluez.properties = {
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
            printing = {
              enable = mkDefault true;
              browsed.enable = mkDefault true;
              drivers = mkDefault (
                with pkgs;
                [
                  gutenprint
                  hplip
                ]
              );
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
            services.flake-update = {
              unitConfig = {
                Description = "Update flake inputs";
                StartLimitIntervalSec = 300;
                StartLimitBurst = 5;
              };
              serviceConfig = {
                ExecStart = "${pkgs.nix}/bin/nix flake update --commit-lock-file --flake /etc/nixos";
                Restart = "on-failure";
                RestartSec = "120s";
                Type = "oneshot";
                User = "root";
                Environment = "HOME=/root";
              };
              wants = [ "network-online.target" ];
              after = [ "network-online.target" ];
              before = [ "nixos-upgrade.service" ];
              path = with pkgs; [
                nix
                git
                host
              ];
              requiredBy = [ "nixos-upgrade.service" ];
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
              extraPortals = (
                with pkgs;
                [
                  xdg-desktop-portal-gnome
                  xdg-desktop-portal-gtk
                ]
              );
              xdgOpenUsePortal = mkDefault true;
            };
          };

          system.autoUpgrade = {
            allowReboot = mkDefault false;
            enable = mkDefault true;
            flake = mkDefault "/etc/nixos";
          };

          users.defaultUserShell = pkgs.bashInteractive;

          zramSwap.enable = mkDefault true;
        };
    };
}
