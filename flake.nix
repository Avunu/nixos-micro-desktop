{
  description = "NixOS Micro Desktop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dank-material-shell = {
      url = "github:AvengeMedia/dankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    {
      nixosModules.microDesktop =
        {
          lib,
          pkgs,
          ...
        }:
        with lib;
        {
          imports = [
            inputs.dank-material-shell.nixosModules.dank-material-shell
            inputs.dank-material-shell.nixosModules.greeter
            inputs.disko.nixosModules.disko
            inputs.home-manager.nixosModules.home-manager
            inputs.niri.nixosModules.niri
            inputs.nix-flatpak.nixosModules.nix-flatpak
          ];
          boot = {
            initrd = {
              availableKernelModules = mkDefault [
                "ahci"
                "ehci_pci"
                "nvme"
                "uhci_hcd"
              ];
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

          disko.devices = {
            disk = {
              main = {
                device = mkDefault "/dev/sda";
                type = "disk";
                content = {
                  type = "gpt";
                  partitions = {
                    ESP = {
                      size = "1G";
                      type = "EF00";
                      content = {
                        type = "filesystem";
                        format = "vfat";
                        mountpoint = "/boot";
                        mountOptions = [
                          "noatime"
                          "umask=0077"
                        ];
                        extraArgs = [
                          "-n"
                          "ESP"
                        ];
                      };
                    };
                    root = {
                      size = "100%";
                      content = {
                        type = "filesystem";
                        format = "f2fs";
                        mountpoint = "/";
                        mountOptions = [
                          "atgc"
                          "compress_algorithm=zstd"
                          "compress_chksum"
                          "gc_merge"
                          "noatime"
                        ];
                        extraArgs = [
                          "-l"
                          "root"
                        ];
                      };
                    };
                  };
                };
              };
            };
          };

          documentation = {
            enable = mkDefault false;
            doc.enable = mkDefault false;
            man.enable = mkDefault false;
            nixos.enable = mkDefault false;
          };

          environment = {
            pathsToLink = [
              "/share"
              "/share/xdg-desktop-portal"
              "/share/applications"
              "/share/icons"
              "/share/pixmaps"
            ];
            sessionVariables = {
              # Keep only essential system-level variables
              LD_LIBRARY_PATH = mkForce "/etc/sane-libs/:/run/opengl-driver/lib";
              OCL_ICD_VENDORS = "/run/opengl-driver/etc/OpenCL/vendors";
              PROTOC = "${pkgs.protobuf}/bin/protoc";
              XDG_CURRENT_DESKTOP = "niri";
              XDG_SESSION_DESKTOP = "niri";
            };
            systemPackages =
              with pkgs;
              lib.flatten [
                [
                  alacritty
                  brightnessctl
                  cava
                  cliphist
                  dnsmasq
                  fuzzel
                  gammastep
                  gcr_4
                  glib
                  gnome-menus
                  gnome-network-displays
                  gnome-software
                  gnome-themes-extra
                  grim
                  gst_all_1.gst-libav
                  gst_all_1.gst-plugins-bad
                  gst_all_1.gst-plugins-base
                  gst_all_1.gst-plugins-good
                  gst_all_1.gst-plugins-ugly
                  gst_all_1.gst-vaapi
                  gst_all_1.gstreamer
                  loupe
                  matugen
                  mission-center
                  nautilus
                  papers
                  pavucontrol
                  playerctl
                  satty
                  shared-mime-info
                  showtime
                  slurp
                  swayidle
                  uutils-coreutils-noprefix
                  wl-clipboard
                  wlr-randr
                  wpa_supplicant
                  wsdd
                  xdg-user-dirs
                  xdg-user-dirs-gtk
                  xdg-utils
                ]
              ];
          };

          fonts.packages = mkDefault (
            with pkgs;
            [
              # Modern GNOME 48 fonts
              adwaita-fonts # Adwaita Sans & Adwaita Mono

              # Essential font families
              dejavu_fonts
              liberation_ttf
              noto-fonts
              noto-fonts-cjk
              noto-fonts-emoji

              # Developer fonts
              fira-code
              fira-code-symbols
              fira-mono
              fira-sans
              meslo-lgs-nf
              source-code
              source-code-pro
              source-sans
              source-sans-pro
              source-serif
              source-serif-pro

              # Popular system fonts
              open-sans
              roboto
              roboto-mono
              roboto-serif
              roboto-slab

              # DMS greeter fonts
              inter
              material-symbols
            ]
          );

          # fileSystems = mkForce {
          #   "/" = {
          #     device = "/dev/disk/by-label/root";
          #     fsType = "f2fs";
          #     options = [
          #       "atgc"
          #       "compress_algorithm=zstd"
          #       "compress_chksum"
          #       "gc_merge"
          #       "noatime"
          #     ];
          #   };
          #   "/boot" = {
          #     device = "/dev/disk/by-label/ESP";
          #     fsType = "vfat";
          #     options = [
          #       "noatime"
          #       "umask=0077"
          #     ];
          #   };
          # };

          hardware = {
            bluetooth.enable = mkDefault true;
            enableRedistributableFirmware = mkDefault true;
            graphics = {
              enable = true;
              extraPackages = with pkgs; [
                intel-media-driver
                intel-vaapi-driver
                libva-utils
                libva1
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

          home-manager = {
            sharedModules = [
              # nix-flatpak.homeManagerModules.nix-flatpak
              inputs.dank-material-shell.homeModules.dankMaterialShell.default
              inputs.dank-material-shell.homeModules.dankMaterialShell.niri
              inputs.niri.homeModules.niri
              (
                {
                  config,
                  lib,
                  pkgs,
                  ...
                }:
                {
                  # Home configuration
                  # home = {
                  # packages = with pkgs; [
                  #   adwaita-qt
                  #   adwaita-qt6
                  #   libdbusmenu
                  #   lxqt.libdbusmenu-lxqt
                  # ];

                  # pointerCursor = {
                  #   dotIcons.enable = mkDefault true;
                  #   gtk.enable = mkDefault true;
                  #   hyprcursor.enable = mkDefault true;
                  #   sway.enable = mkDefault true;
                  #   x11.enable = mkDefault true;
                  #   name = mkDefault "Adwaita";
                  #   package = mkDefault pkgs.adwaita-icon-theme;
                  #   size = mkDefault 24;
                  # };

                  # sessionVariables = {
                  #   CLUTTER_BACKEND = "wayland";
                  #   EGL_PLATFORM = "wayland";
                  #   ELECTRON_OZONE_PLATFORM_HINT = "wayland";
                  #   GDK_BACKEND = "wayland";
                  #   GDK_PLATFORM = "wayland";
                  #   GTK_BACKEND = "wayland";
                  #   GTK_IM_MODULE = "wayland";
                  #   MOZ_ENABLE_WAYLAND = "1";
                  #   MOZ_USE_XINPUT2 = "1";
                  #   NIXOS_OZONE_WL = "1";
                  #   NIXPKGS_ALLOW_UNFREE = "1";
                  #   QML_DISABLE_DISK_CACHE = "1";
                  #   QT_IM_MODULE = "wayland";
                  #   QT_QPA_PLATFORM = "wayland";
                  #   QT_SCALE_FACTOR_ROUNDING_POLICY = "RoundPreferFloor";
                  #   QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
                  #   SDL_VIDEODRIVER = "wayland";
                  #   XCURSOR_THEME = "Adwaita";
                  #   XDG_CURRENT_DESKTOP = "niri";
                  #   XDG_SESSION_DESKTOP = "niri";
                  #   XDG_SESSION_TYPE = "wayland";
                  # };
                  # };

                  # # dconf settings
                  # dconf = {
                  #   enable = mkDefault true;
                  #   settings."org/gnome/desktop/interface".color-scheme = mkDefault "prefer-dark";
                  # };

                  # # GTK configuration
                  # gtk = {
                  #   enable = mkDefault true;
                  #   cursorTheme = {
                  #     package = mkDefault pkgs.adwaita-icon-theme;
                  #     name = mkDefault "Adwaita";
                  #   };
                  #   iconTheme = {
                  #     name = mkDefault "Adwaita";
                  #     package = mkDefault pkgs.adwaita-icon-theme;
                  #   };
                  # };

                  programs = {
                    dank-material-shell = {
                      enable = mkDefault true;
                      enableSystemMonitoring = mkDefault false;
                      enableClipboard = mkDefault true;
                      enableVPN = mkDefault true;
                      enableBrightnessControl = mkDefault true;
                      enableColorPicker = mkDefault true;
                      niri = {
                        enableKeybinds = mkDefault true;
                        enableSpawn = mkDefault true;
                      };
                    };
                    niri = {
                      enable = true;
                      package = mkForce pkgs.niri;
                      config = import "${inputs.niri}/default-config.kdl.nix" inputs { inherit pkgs; };
                    };
                    # quickshell = {
                    #   enable = true;
                    #   package = mkForce pkgs.quickshell;
                    #   configs.dms = "${dank-material-shell.packages.x86_64-linux.dank-material-shell}/etc/xdg/quickshell/dms";
                    #   activeConfig = "dms";
                    #   systemd = {
                    #     enable = true;
                    #     target = "graphical-session.target";
                    #   };
                    # };
                  };
                  # qt = {
                  #   enable = mkDefault true;
                  #   platformTheme.name = mkDefault "qtct";
                  #   style.package = mkDefault pkgs.adwaita-qt6;
                  # };

                  # services = {
                  #   # Clipboard manager
                  #   cliphist = {
                  #     enable = mkDefault true;
                  #   };

                  #   # Automatic suspend after 10 minutes of inactivity
                  #   swayidle = {
                  #     enable = mkDefault false;
                  #     systemdTarget = mkDefault "niri.service";
                  #     events = mkDefault [
                  #       {
                  #         event = "before-sleep";
                  #         command = "${pkgs.systemd}/bin/loginctl lock-session";
                  #       }
                  #     ];
                  #     timeouts = mkDefault [
                  #       {
                  #         timeout = 600;
                  #         command = "${pkgs.systemd}/bin/systemctl suspend";
                  #       }
                  #     ];
                  #   };
                  # };

                  # wayland.systemd.target = mkDefault "niri.service";

                  # # XDG configuration
                  # xdg = {
                  #   enable = mkDefault true;
                  #   mime.enable = mkDefault true;
                  #   # mimeApps.enable = mkDefault true;
                  #   portal = {
                  #     enable = mkDefault true;
                  #     configPackages = mkDefault [ pkgs.niri ];
                  #     extraPortals = mkDefault (
                  #       with pkgs;
                  #       [
                  #         xdg-desktop-portal-gnome
                  #         xdg-desktop-portal-gtk
                  #       ]
                  #     );
                  #     xdgOpenUsePortal = mkDefault true;
                  #   };
                  #   systemDirs.data = [
                  #     "/var/lib/flatpak/exports/share"
                  #     "${config.home.homeDirectory}/.local/share/flatpak/exports/share"
                  #   ];
                  #   userDirs = {
                  #     enable = mkDefault true;
                  #     createDirectories = mkDefault true;
                  #   };
                  # };

                  # Add D-Bus environment update and polkit-gnome
                  # systemd.user.services = {
                  #   # Ensure polkit-gnome starts after niri and has proper environment
                  #   polkit-gnome-authentication-agent-1 = {
                  #     Unit = {
                  #       Description = "PolicyKit Authentication Agent";
                  #       After = [
                  #         "graphical-session.target"
                  #         "niri.service"
                  #       ];
                  #       PartOf = [ "graphical-session.target" ];
                  #     };
                  #     Service = {
                  #       Type = "simple";
                  #       ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
                  #       Restart = "on-failure";
                  #       RestartSec = 1;
                  #       TimeoutStopSec = 10;
                  #     };
                  #     Install = {
                  #       WantedBy = [ "graphical-session.target" ];
                  #     };
                  #   };

                  #   dbus-update-env = {
                  #     Unit = {
                  #       Description = "Update D-Bus activation environment";
                  #       After = [ "graphical-session.target" ];
                  #       PartOf = [ "graphical-session.target" ];
                  #     };
                  #     Service = {
                  #       Type = "oneshot";
                  #       ExecStart = "${lib.getBin pkgs.dbus}/bin/dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=$XDG_CURRENT_DESKTOP PATH";
                  #       RemainAfterExit = true;
                  #     };
                  #     Install = {
                  #       WantedBy = [ "graphical-session.target" ];
                  #     };
                  #   };
                  # };
                }
              )
            ];
          };

          # i18n.inputMethod = {
          #   type = mkDefault "fcitx5";
          #   fcitx5 = {
          #     addons = with pkgs; [
          #       fcitx5-configtool
          #       fcitx5-gtk
          #       catppuccin-fcitx5
          #     ];
          #     settings.addons = mkDefault { pinyin.globalSection.EmojiEnabled = "True"; };
          #     waylandFrontend = mkDefault true;
          #   };
          # };

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
              auto-optimise-store = true;
              experimental-features = [
                "nix-command"
                "flakes"
              ];
              substituters = [
                "https://cache.nixos.org?priority=40"
                "https://nix-community.cachix.org?priority=41"
                "https://niri.cachix.org?priority=42"
              ];
              trusted-public-keys = [
                "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
                "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
                "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
              ];
              trusted-users = [
                "root"
                "nixos"
                "@wheel"
              ];
            };
          };

          nixpkgs = {
            config = {
              allowUnfree = mkDefault true;
            };
            # overlays = [ niri.overlays.niri ];
          };

          programs = {
            appimage.enable = mkDefault true;
            dconf.enable = mkDefault true;
            dank-material-shell = {
              enable = mkDefault true;
              greeter = {
                enable = mkDefault true;
                compositor.name = mkDefault "niri";
              };
              systemd.enable = mkDefault false;
            };
            git = {
              enable = true;
              config.safe.directory = [ "/etc/nixos" ];
            };
            gnupg.agent = {
              enable = mkDefault true;
              enableSSHSupport = mkDefault true;
              pinentryPackage = mkDefault pkgs.pinentry-gnome3;
            };
            # niri = {
            #   enable = mkDefault true;
            #   package = mkForce pkgs.niri;
            # };
            nix-ld = {
              enable = mkDefault true;
              package = pkgs.nix-ld;
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
            colord.enable = mkDefault true;
            dbus = {
              implementation = mkDefault "broker";
              packages = with pkgs; [
                dconf
                gcr
                gnome-keyring
                libdbusmenu
                lxqt.libdbusmenu-lxqt
              ];
            };
            displayManager = {
              defaultSession = "niri";
              sessionPackages = [ pkgs.niri ];
            };
            greetd = {
              enable = mkDefault true;
              settings = {
                default_session = {
                  user = mkDefault "greeter";
                };
              };
            };
            flatpak = {
              enable = mkDefault true;
              overrides = {
                global = {
                  Context = {
                    sockets = [
                      "wayland"
                      "!fallback-x11"
                      "!x11"
                    ];
                    filesystems = [
                      "/run/current-system/sw/share/X11/fonts:ro;/nix/store:ro;/run/dbus/system_bus_socket:rw"
                    ];
                  };
                  Environment = {
                    XCURSOR_PATH = "/run/host/user-share/icons:/run/host/share/icons";
                  };
                };
                "com.synology.SynologyDrive".Context.sockets = [ "x11" ];
                "net.xmind.XMind".Context.sockets = [ "x11" ];
                "net.xmind.XMind8".Context.sockets = [ "x11" ];
                "org.onlyoffice.desktopeditors".Context.sockets = [ "x11" ];
                "com.logseq.Logseq".Context.sockets = [ "x11" ];
              };
              packages = [
                "org.freedesktop.Platform.ffmpeg-full/x86_64/24.08"
                "org.freedesktop.Platform.GStreamer.gstreamer-vaapi/x86_64/23.08"
                "org.gnome.Platform/x86_64/48"
                "org.gtk.Gtk3theme.adw-gtk3-dark"
                "org.gtk.Gtk3theme.adw-gtk3"
              ];
              update.auto.enable = mkDefault true;
              update.auto.onCalendar = mkDefault "weekly";
            };
            fstrim = {
              enable = mkDefault true;
              interval = mkDefault "daily";
            };
            fwupd.enable = mkDefault true;
            gnome = {
              glib-networking.enable = mkDefault true;
              gnome-keyring.enable = mkDefault true;
              gnome-online-accounts.enable = mkDefault true;
              gnome-settings-daemon.enable = mkDefault true;
              # gnome-user-share.enable = mkDefault false;
              # localsearch.enable = mkDefault true;
              # rygel.enable = mkDefault true;
              # sushi.enable = mkDefault true;
              # tinysparql.enable = mkDefault true;
            };
            gvfs = {
              enable = mkDefault true;
              package = mkDefault pkgs.gnome.gvfs;
            };
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
              webInterface = mkDefault false;
            };
            samba-wsdd.discovery = mkDefault true;
            system-config-printer.enable = mkDefault true;
            udev.packages = with pkgs; [
              gnome-settings-daemon
            ];
            udisks2.enable = mkDefault true;
            upower.enable = mkDefault true;
          };

          security = {
            pam.services.login.enableGnomeKeyring = mkDefault true;
            # polkit.enable = mkDefault true;
            rtkit.enable = mkDefault true;
            tpm2.enable = mkDefault true;
          };

          systemd = {
            packages = with pkgs; [
              niri
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
              greetd.serviceConfig = {
                Type = "idle";
                StandardInput = "tty";
                StandardOutput = "tty";
                StandardError = "journal"; # Without this errors will spam on screen
                # Without these bootlogs will spam on screen
                TTYReset = true;
                TTYVHangup = true;
                TTYVTDisallocate = true;
              };
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
