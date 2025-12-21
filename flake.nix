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
              "/share/thumbnailers"
            ];
            sessionVariables = {
              # Keep only essential system-level variables
              # LD_LIBRARY_PATH = mkForce "/etc/sane-libs/:/run/opengl-driver/lib";
              OCL_ICD_VENDORS = "/run/opengl-driver/etc/OpenCL/vendors";
              PROTOC = "${pkgs.protobuf}/bin/protoc";
              XDG_CURRENT_DESKTOP = "niri";
              XDG_SESSION_DESKTOP = "niri";
              QT_QPA_PLATFORMTHEME = "gtk3";
              GTK_THEME = "adw-gtk3";
            };
            systemPackages =
              with pkgs;
              lib.flatten [
                [
                  adw-gtk3
                  alacritty
                  brightnessctl
                  cava
                  cliphist
                  dnsmasq
                  ffmpeg-headless
                  ffmpegthumbnailer
                  gammastep
                  gcr_4
                  gdk-pixbuf
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
                  libheif
                  libheif.out
                  loupe
                  matugen
                  mission-center
                  nautilus
                  papers
                  playerctl
                  satty
                  shared-mime-info
                  showtime
                  slurp
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

          gtk.iconCache.enable = mkDefault true;

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
              inputs.dank-material-shell.homeModules.default
              inputs.dank-material-shell.homeModules.niri
              (
                {
                  config,
                  lib,
                  pkgs,
                  ...
                }:
                let
                  # Manually define default niri keybindings in settings format
                  # This allows proper merging with DMS keybindings
                  defaultNiriBinds = with config.lib.niri.actions; {
                    "Mod+Shift+Slash".action = show-hotkey-overlay;
                    "Mod+T".action = spawn "alacritty";
                    # "Mod+D".action = spawn "fuzzel";
                    "Mod+Q".action = close-window;
                    "Mod+Left".action = focus-column-left;
                    "Mod+Down".action = focus-window-down;
                    "Mod+Up".action = focus-window-up;
                    "Mod+Right".action = focus-column-right;
                    "Mod+H".action = focus-column-left;
                    "Mod+J".action = focus-window-down;
                    "Mod+K".action = focus-window-up;
                    "Mod+L".action = focus-column-right;
                    "Mod+Ctrl+Left".action = move-column-left;
                    "Mod+Ctrl+Down".action = move-window-down;
                    "Mod+Ctrl+Up".action = move-window-up;
                    "Mod+Ctrl+Right".action = move-column-right;
                    "Mod+Ctrl+H".action = move-column-left;
                    "Mod+Ctrl+J".action = move-window-down;
                    "Mod+Ctrl+K".action = move-window-up;
                    "Mod+Ctrl+L".action = move-column-right;
                    "Mod+Home".action = focus-column-first;
                    "Mod+End".action = focus-column-last;
                    "Mod+Ctrl+Home".action = move-column-to-first;
                    "Mod+Ctrl+End".action = move-column-to-last;
                    "Mod+Shift+Left".action = focus-monitor-left;
                    "Mod+Shift+Down".action = focus-monitor-down;
                    "Mod+Shift+Up".action = focus-monitor-up;
                    "Mod+Shift+Right".action = focus-monitor-right;
                    "Mod+Shift+H".action = focus-monitor-left;
                    "Mod+Shift+J".action = focus-monitor-down;
                    "Mod+Shift+K".action = focus-monitor-up;
                    "Mod+Shift+L".action = focus-monitor-right;
                    "Mod+Shift+Ctrl+Left".action = move-column-to-monitor-left;
                    "Mod+Shift+Ctrl+Down".action = move-column-to-monitor-down;
                    "Mod+Shift+Ctrl+Up".action = move-column-to-monitor-up;
                    "Mod+Shift+Ctrl+Right".action = move-column-to-monitor-right;
                    "Mod+Shift+Ctrl+H".action = move-column-to-monitor-left;
                    "Mod+Shift+Ctrl+J".action = move-column-to-monitor-down;
                    "Mod+Shift+Ctrl+K".action = move-column-to-monitor-up;
                    "Mod+Shift+Ctrl+L".action = move-column-to-monitor-right;
                    "Mod+Page_Down".action = focus-workspace-down;
                    "Mod+Page_Up".action = focus-workspace-up;
                    "Mod+U".action = focus-workspace-down;
                    "Mod+I".action = focus-workspace-up;
                    "Mod+Ctrl+Page_Down".action = move-column-to-workspace-down;
                    "Mod+Ctrl+Page_Up".action = move-column-to-workspace-up;
                    "Mod+Ctrl+U".action = move-column-to-workspace-down;
                    "Mod+Ctrl+I".action = move-column-to-workspace-up;
                    "Mod+Shift+Page_Down".action = move-workspace-down;
                    "Mod+Shift+Page_Up".action = move-workspace-up;
                    "Mod+Shift+U".action = move-workspace-down;
                    "Mod+Shift+I".action = move-workspace-up;
                    # "Mod+1".action = focus-workspace 1;
                    # "Mod+2".action = focus-workspace 2;
                    # "Mod+3".action = focus-workspace 3;
                    # "Mod+4".action = focus-workspace 4;
                    # "Mod+5".action = focus-workspace 5;
                    # "Mod+6".action = focus-workspace 6;
                    # "Mod+7".action = focus-workspace 7;
                    # "Mod+8".action = focus-workspace 8;
                    # "Mod+9".action = focus-workspace 9;
                    # "Mod+Ctrl+1".action = move-column-to-workspace 1;
                    # "Mod+Ctrl+2".action = move-column-to-workspace 2;
                    # "Mod+Ctrl+3".action = move-column-to-workspace 3;
                    # "Mod+Ctrl+4".action = move-column-to-workspace 4;
                    # "Mod+Ctrl+5".action = move-column-to-workspace 5;
                    # "Mod+Ctrl+6".action = move-column-to-workspace 6;
                    # "Mod+Ctrl+7".action = move-column-to-workspace 7;
                    # "Mod+Ctrl+8".action = move-column-to-workspace 8;
                    # "Mod+Ctrl+9".action = move-column-to-workspace 9;
                    "Mod+Period".action = expel-window-from-column;
                    "Mod+R".action = switch-preset-column-width;
                    "Mod+F".action = maximize-column;
                    "Mod+Shift+F".action = fullscreen-window;
                    "Mod+C".action = center-column;
                    "Mod+Minus".action = set-column-width "-10%";
                    "Mod+Equal".action = set-column-width "+10%";
                    "Mod+Shift+Minus".action = set-window-height "-10%";
                    "Mod+Shift+Equal".action = set-window-height "+10%";
                    # "Print".action = screenshot;
                    # "Ctrl+Print".action = screenshot-screen;
                    # "Alt+Print".action = screenshot-window;
                    "Mod+Shift+E".action = quit;
                    "Mod+Shift+P".action = power-off-monitors;
                  };
                in
                {
                  # Home configuration
                  home = {
                    pointerCursor = {
                      dotIcons.enable = mkDefault true;
                      gtk.enable = mkDefault true;
                      hyprcursor.enable = mkDefault true;
                      sway.enable = mkDefault true;
                      x11.enable = mkDefault true;
                      name = mkDefault "Adwaita";
                      package = mkDefault pkgs.adwaita-icon-theme;
                      size = mkDefault 24;
                    };
                  };

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
                      enableVPN = mkDefault true;
                      niri = {
                        enableKeybinds = mkDefault true;
                        enableSpawn = mkDefault false;
                      };
                      # Also override at home-manager level
                      quickshell.package = mkForce pkgs.quickshell;
                    };
                    niri = {
                      # Merge default keybindings with DMS settings
                      # DMS binds will override any conflicts due to merge order
                      settings = {
                        binds = lib.mkMerge [
                          (lib.mkBefore defaultNiriBinds)
                          # DMS adds its binds here via programs.niri.settings.binds
                        ];
                      };
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

                  wayland.systemd.target = mkDefault "niri.service";

                  # # XDG configuration
                  # xdg = {
                  #   enable = mkDefault true;
                  #   mime.enable = mkDefault true;
                  #   mimeApps.enable = mkDefault true;
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
                  #     config = {
                  #       common = {
                  #         default = [ "gnome" "gtk" ];
                  #       };
                  #       niri = {
                  #         default = [ "gnome" "gtk" ];
                  #         "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
                  #       };
                  #     };
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
                  
                }
              )
            ];
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
                # Override the quickshell package to use nixpkgs version
                quickshell.package = mkForce pkgs.quickshell;
              };
              systemd.enable = mkDefault true;
              # Override the quickshell package to use nixpkgs version
              quickshell.package = mkForce pkgs.quickshell;
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

          qt = {
            enable = mkDefault true;
            # platformTheme = mkDefault "gnome";
            style = mkDefault "adwaita";
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
                nautilus
              ];
            };
            # displayManager = {
            #   defaultSession = "niri";
            #   sessionPackages = [ pkgs.niri ];
            # };
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
            polkit.enable = mkDefault true;
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

          xdg = {
            autostart.enable = mkDefault true;
            icons.enable = mkDefault true;
            menus.enable = mkDefault true;
            mime.enable = mkDefault true;
            portal = {
              enable = mkDefault true;
              configPackages = mkDefault [ pkgs.niri ];
              extraPortals = mkDefault (
                with pkgs;
                [
                  xdg-desktop-portal-gnome
                  xdg-desktop-portal-gtk
                ]
              );
              xdgOpenUsePortal = mkDefault true;
              config = {
                common = {
                  default = [
                    "gnome"
                    "gtk"
                  ];
                };
                niri = {
                  default = [
                    "gnome"
                    "gtk"
                  ];
                  "org.freedesktop.impl.portal.Access" = "gtk";
                  "org.freedesktop.impl.portal.FileChooser" = "gtk";
                  "org.freedesktop.impl.portal.Notification" = "gtk";
                  "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
                  "org.freedesktop.impl.portal.Settings" = "gnome";
                };
              };
            };
            sounds.enable = mkDefault true;
          };

          zramSwap.enable = mkDefault true;
        };
    };
}
