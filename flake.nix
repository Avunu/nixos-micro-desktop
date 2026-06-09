{
  description = "NixOS Micro Desktop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-packagekit = {
      url = "github:Avunu/nix-profile-packagekit-backend";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      lib = nixpkgs.lib;
    in
    {
      devShells.x86_64-linux.default =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        pkgs.mkShell {
          nativeBuildInputs = [
            (pkgs.writeShellScriptBin "update-flake" ''
              git pull
              nix flake update
              git add flake.lock
              git commit -m "chore: update flake"
              git push
            '')
          ];
          packages = [
            pkgs.mcp-nixos
          ];
        };
      nixosModules.microDesktop =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        with lib;
        let
          cfg = config.microDesktop;
          systemUpgradeScript = pkgs.writeShellApplication {
            name = "system-upgrade";
            runtimeInputs = with pkgs; [
              git
              nix
              nixos-rebuild
            ];
            text = ''
              ${lib.getExe pkgs.nix} flake update --flake /etc/nixos
              ${lib.getExe pkgs.nixos-rebuild} switch --flake /etc/nixos
            '';
          };
        in
        {
          imports = [
            inputs.disko.nixosModules.disko
            inputs.nix-packagekit.nixosModules.default
          ];

          options.microDesktop = {
            hostName = mkOption {
              type = types.str;
              description = "Hostname for the system";
            };
            diskDevice = mkOption {
              type = types.str;
              default = "/dev/sda";
              description = "Disk device for installation";
            };
            bootMode = mkOption {
              type = types.enum [
                "uefi"
                "legacy"
              ];
              default = "uefi";
              description = "Boot mode: uefi (systemd-boot) or legacy (GRUB)";
            };
            timeZone = mkOption {
              type = types.str;
              default = "America/New_York";
              description = "System timezone";
            };
            locale = mkOption {
              type = types.str;
              default = "en_US.UTF-8";
              description = "System locale";
            };
            username = mkOption {
              type = types.str;
              description = "Primary user name";
            };
            initialPassword = mkOption {
              type = types.str;
              default = "password";
              description = "Initial password for the user";
            };
            stateVersion = mkOption {
              type = types.str;
              default = "25.11";
              description = "NixOS state version";
            };
            extraPackages = mkOption {
              type = types.listOf types.package;
              default = [ ];
              description = "Additional packages to install";
            };
            enableSsh = mkOption {
              type = types.bool;
              default = false;
              description = "Enable SSH server";
            };
            sshPasswordAuth = mkOption {
              type = types.bool;
              default = true;
              description = "Allow password authentication for SSH";
            };
            sshRootLogin = mkOption {
              type = types.str;
              default = "yes";
              description = "Permit root login via SSH";
            };
            enableVpn = mkOption {
              type = types.bool;
              default = false;
              description = "Enable VPN support (installs NetworkManager VPN plugins)";
            };
          };

          config = {
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
                # Note: i915.enable_guc removed - not all Intel GPUs support GuC/HuC
                # Add it per-device in local flake if needed (Gen9+ with firmware support)
                "i915.modeset=1"
                "i915.enable_fbc=1" # Framebuffer compression for power savings
                "loglevel=3"
                "mem_sleep_default=deep"
                "pcie_aspm.policy=powersupersave"
                "quiet"
                "rd.systemd.show_status=false"
                "systemd.show_status=false"
                "rd.udev.log_level=3"
                "splash"
                "udev.log_priority=3"
              ];
              # Increase readahead for better SQLite read performance with f2fs compression
              kernelModules = mkDefault [ "bfq" ];
              kernel.sysctl = {
                "vm.swappiness" = mkDefault 10; # Reduce swap pressure for better DB performance
                "vm.vfs_cache_pressure" = mkDefault 50; # Keep inodes/dentries cached longer for SQLite
                "vm.dirty_ratio" = mkDefault 15; # Allow more dirty pages before forced writeback
                "vm.dirty_background_ratio" = mkDefault 5; # Start background writeback early
                "vm.page-cluster" = mkDefault 0; # Read single pages from swap (better for zram + random I/O)
              };
              consoleLogLevel = mkDefault 0;
              loader = mkMerge [
                (mkIf (cfg.bootMode == "uefi") {
                  efi.canTouchEfiVariables = mkDefault true;
                  systemd-boot = {
                    configurationLimit = mkDefault 10;
                    enable = mkDefault true;
                  };
                })
                (mkIf (cfg.bootMode == "legacy") {
                  grub = {
                    enable = mkDefault true;
                    device = cfg.diskDevice;
                  };
                })
                ({ timeout = mkDefault 2; })
              ];
              plymouth.enable = mkDefault true;
              supportedFilesystems = {
                ext3 = mkDefault false;
                ntfs3 = mkDefault false;
                xfs = mkDefault false;
                zfs = mkDefault false;
              };
              swraid.enable = mkDefault false;
            };

            boot.tmp = {
              useTmpfs = mkDefault true;
              tmpfsSize = mkDefault "50%"; # Half of RAM; prevents runaway usage
            };

            console = {
              keyMap = mkDefault "us";
              packages = mkDefault [ pkgs.terminus_font ];
            };

            disko.devices = mkDefault {
              disk = {
                main = {
                  device = cfg.diskDevice;
                  type = "disk";
                  content = mkMerge [
                    (mkIf (cfg.bootMode == "uefi") {
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
                              "compress_algorithm=zstd:1" # Level 1: minimal CPU overhead, reduces I/O bandwidth
                              "compress_cache" # Cache decompressed pages for hot data (SQLite, desktop apps)
                              "compress_chksum"
                              "compress_extension=*" # Compress all files by default
                              "gc_merge"
                              "noatime"
                              "nodiscard" # Use scheduled fstrim instead of synchronous discard
                            ];
                            extraArgs = [
                              "-O"
                              "extra_attr,compression" # Enable compression feature at format time
                              "-l"
                              "root"
                            ];
                          };
                        };
                      };
                    })
                    (mkIf (cfg.bootMode == "legacy") {
                      type = "gpt";
                      partitions = {
                        boot = {
                          size = "1M";
                          type = "EF02";
                        };
                        root = {
                          size = "100%";
                          content = {
                            type = "filesystem";
                            format = "f2fs";
                            mountpoint = "/";
                            mountOptions = [
                              "atgc"
                              "compress_algorithm=zstd:1" # Level 1: minimal CPU overhead, reduces I/O bandwidth
                              "compress_cache" # Cache decompressed pages for hot data (SQLite, desktop apps)
                              "compress_chksum"
                              "compress_extension=*" # Compress all files by default
                              "gc_merge"
                              "noatime"
                              "nodiscard" # Use scheduled fstrim instead of synchronous discard
                            ];
                            extraArgs = [
                              "-O"
                              "extra_attr,compression" # Enable compression feature at format time
                              "-l"
                              "root"
                            ];
                          };
                        };
                      };
                    })
                  ];
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
              etc = {
                # Deploy niri config system-wide
                "niri/config.kdl".source = ./configs/niri-global.kdl;
                # deploy default GTK config
                "gtk-3.0/settings.ini".source = ./configs/gtk-3.0-settings.ini;
                "gtk-4.0/settings.ini".source = ./configs/gtk-4.0-settings.ini;
                # "xdg/qt6ct/qt6ct.conf".source = ./configs/qt6ct.conf;
                # Fix Electron CHROME_DESKTOP on NixOS: preload script that derives
                # the correct .desktop name from process.argv at JS init time.
                "environment.d/60-electron-chrome-desktop.conf".text = ''
                  NODE_OPTIONS="--require=${./scripts/electron-chrome-desktop-fix.js}"
                '';
                "nix/nixpkgs-config.nix".text = lib.mkDefault ''
                  {
                    allowUnfree = true;
                  }
                '';
                # "xdg/menus/applications.menu".source =
                #   "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
              };
              pathsToLink = [
                "/share/app-info"
                "/share/applications"
                "/share/gtk-3.0"
                "/share/gtk-4.0"
                "/share/icons"
                "/share/metainfo"
                "/share/pixmaps"
                "/share/thumbnailers"
                "/share/xdg-desktop-portal"
              ];
              shells = with pkgs; [
                bash
                nushell
              ];
              variables = {
                CLUTTER_BACKEND = "wayland";
                EGL_PLATFORM = "wayland";
                ELECTRON_OZONE_PLATFORM_HINT = "wayland";
                GDK_BACKEND = "wayland";
                GDK_PLATFORM = "wayland";
                GTK_BACKEND = "wayland";
                # GTK_THEME = "adw-gtk";
                MOZ_ENABLE_WAYLAND = "1";
                NIXPKGS_ALLOW_UNFREE = "1";
                OCL_ICD_VENDORS = "/run/opengl-driver/etc/OpenCL/vendors";
                MU_QT_QPA_PLATFORM = "wayland";
                PROTOC = "${pkgs.protobuf}/bin/protoc";
                QML_DISABLE_DISK_CACHE = "1";
                QSG_RHI_BACKEND = "vulkan";
                QT_QPA_PLATFORM = "wayland";
                QT_QPA_PLATFORMTHEME = "gtk3";
                QT_SCALE_FACTOR_ROUNDING_POLICY = "RoundPreferFloor";
                QT_STYLE_OVERRIDE = "Fusion";
                SAL_ENABLESKIA = "1";
                SAL_FORCESKIA = "1";
                SAL_SKIA = "vulkan";
                SDL_SOUNDFONTS = "${pkgs.soundfont-fluid}/share/soundfonts/FluidR3_GM.sf2";
                SDL_VIDEODRIVER = "wayland";
                TERMINAL = getExe pkgs.ghostty;
                XDG_CURRENT_DESKTOP = "niri";
                XDG_SESSION_DESKTOP = "niri";
                XDG_SESSION_TYPE = "wayland";
                # SQLite performance: use /tmp (tmpfs) for temp files instead of f2fs
                SQLITE_TMPDIR = "/tmp";
              };
              systemPackages =
                with pkgs;
                lib.flatten [
                  [
                    (writeShellScriptBin "profile-upgrade" ''
                      nix profile upgrade --all --impure
                    '')
                    (writeShellScriptBin "restart-shell" ''
                      systemctl --user restart dms.service
                    '')
                    # Aspell Dictionaries
                    (pkgs.aspellWithDicts (dicts: [
                      dicts.en
                      dicts.en-computers
                    ]))
                    # Hunspell Dictionaries
                    (pkgs.hunspell.withDicts (dicts: [
                      dicts.en_GB-ize
                      dicts.en_US
                    ]))
                    adw-gtk3
                    adwaita-icon-theme
                    adwaita-qt
                    adwaita-qt6
                    brightnessctl
                    cava
                    cliphist
                    darkly
                    decibels
                    dnsmasq
                    dsearch
                    ffmpeg-headless
                    ffmpegthumbnailer
                    fprintd
                    gammastep
                    gcr_4
                    gdk-pixbuf
                    ghostty
                    glib
                    gnome-menus
                    gnome-network-displays
                    gnome-packagekit
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
                    gtk4.out
                    # kdePackages.breeze
                    # kdePackages.breeze-gtk
                    # kdePackages.breeze-icons
                    key-rack
                    libdbusmenu
                    libheif
                    libheif.out
                    libmtp
                    libsecret
                    # libsForQt5.qt5ct
                    loupe
                    lxqt.libdbusmenu-lxqt
                    matugen
                    mission-center
                    morewaita-icon-theme
                    nautilus
                    niri
                    packagekit
                    papers
                    playerctl
                    # qt6Packages.qt6ct
                    ripgrep
                    satty
                    shared-mime-info
                    showtime
                    slurp
                    systemUpgradeScript
                    uutils-coreutils-noprefix
                    wl-clipboard
                    wlr-randr
                    wpa_supplicant
                    wsdd
                    xdg-user-dirs
                    xdg-user-dirs-gtk
                    xdg-utils
                  ]
                  cfg.extraPackages
                ];
              sessionVariables = {
                NIXOS_OZONE_WL = "1";
                # Curated XDG_DATA_DIRS to prevent duplicate D-Bus service warnings
                # Only include paths that are actually needed:
                # - User's local share (for local .desktop files)
                # - User's nix-profile (for nix profile installed packages)
                # - Display manager session data (for .desktop session files)
                # - System path (canonical aggregation of all system packages)
                # mkForce overrides display-managers and nix-packagekit defaults
                XDG_DATA_DIRS = mkForce "$HOME/.local/share:$HOME/.nix-profile/share:${config.services.displayManager.sessionData.desktops}/share:/run/current-system/sw/share";
              };
            };

            fonts = {
              enableDefaultPackages = mkDefault true;
              packages = mkDefault (
                with pkgs;
                [
                  # Modern GNOME fonts
                  adwaita-fonts

                  # Essential font families
                  dejavu_fonts
                  liberation_ttf
                  noto-fonts
                  noto-fonts-cjk-sans
                  noto-fonts-color-emoji

                  # Developer fonts
                  cascadia-code
                  fira-code
                  fira-code-symbols
                  fira-mono
                  fira-sans
                  meslo-lgs-nf
                  source-code-pro
                  source-sans-pro
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
              fontconfig = {
                enable = true;
                defaultFonts = {
                  sansSerif = [
                    "Adwaita Sans"
                    "Inter"
                    "Liberation Sans"
                  ];
                  serif = [
                    "Liberation Serif"
                    "DejaVu Serif"
                  ];
                  monospace = [
                    "Cascadia Code"
                    "Adwaita Mono"
                    "Liberation Mono"
                  ];
                  emoji = [
                    "Noto Color Emoji"
                    "Noto Emoji"
                  ];
                };
              };
            };

            gtk.iconCache.enable = mkDefault true;

            powerManagement = {
              enable = mkDefault true;
              powertop.enable = mkDefault false;
            };

            hardware = {
              bluetooth.enable = mkDefault true;
              enableRedistributableFirmware = mkDefault true;
              graphics = {
                enable = true;
                extraPackages = with pkgs; [
                  intel-media-driver
                  intel-vaapi-driver
                  ocl-icd
                  vulkan-loader
                ];
              };
              sane = {
                enable = mkDefault true;
                extraBackends = mkDefault (
                  with pkgs;
                  [
                    sane-airscan
                    sane-backends
                  ]
                );
              };
              sensor.iio.enable = mkDefault true;
            };

            networking = {
              hostName = cfg.hostName;
              networkmanager = {
                enable = mkDefault true;
                plugins = mkIf cfg.enableVpn (
                  mkDefault (
                    with pkgs;
                    [
                      networkmanager-openvpn
                      networkmanager-vpnc
                      networkmanager-openconnect
                      networkmanager-l2tp
                    ]
                  )
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
                  "cgroups"
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
                  cfg.username
                  "@wheel"
                ];
                use-cgroups = true;
                use-xdg-base-directories = true;
              };
            };

            nixpkgs.config = {
              allowBroken = true;
              allowUnfree = true;
              allowUnfreePredicate = _: true;
              permittedInsecurePackages = [
                "electron-39.8.10"
              ];
            };

            nixpkgs.overlays = [ ];

            programs = {
              appimage.enable = mkDefault true;
              dconf.enable = mkDefault true;

              # DMS Shell (nixpkgs native)
              dms-shell = {
                enable = mkDefault true;
                enableCalendarEvents = mkDefault false; # todo: re-enable when khal is fixed upstream
                enableSystemMonitoring = mkDefault true;
                enableVPN = cfg.enableVpn;
                systemd = {
                  enable = mkDefault true;
                  target = "graphical-session.target";
                };
              };

              git = {
                enable = true;
                config.safe.directory = [ "/etc/nixos" ];
              };
              gnupg.agent = {
                enable = mkDefault true;
                enableSSHSupport = mkDefault false; # Using gcr-ssh-agent for SSH
                pinentryPackage = mkDefault pkgs.pinentry-gnome3;
              };
              niri = {
                enable = mkDefault true;
                useNautilus = mkDefault true;
              };
              # uwsm = {
              #   enable = mkDefault true;
              #   waylandCompositors.niri = {
              #     prettyName = "Niri";
              #     comment = "A scrollable-tiling Wayland compositor";
              #     binPath = getExe pkgs.niri;
              #     extraArgs = [ "--session" ];
              #   };
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

            # qt = {
            #   enable = mkDefault true;
            #   platformTheme = mkDefault "qt5ct";
            # };

            services = {
              accounts-daemon.enable = mkDefault true;
              avahi = {
                enable = mkDefault true;
                nssmdns4 = mkDefault true;
                nssmdns6 = mkDefault true;
                publish = {
                  addresses = mkDefault true;
                  enable = mkDefault true;
                  workstation = mkDefault true;
                };
              };
              bpftune.enable = mkDefault true;
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
                dms-greeter = {
                  enable = mkDefault true;
                  compositor.name = "niri";
                };
                sessionPackages = with pkgs; [
                  niri
                ];
              };
              fprintd = {
                enable = mkDefault true;
                package = mkDefault pkgs.fprintd-tod;
                tod = {
                  enable = mkDefault true;
                  driver = mkDefault pkgs.libfprint-2-tod1-goodix;
                };
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
                localsearch.enable = mkDefault true;
                sushi.enable = mkDefault true;
                tinysparql.enable = mkDefault true;
              };
              greetd = {
                enable = mkDefault true;
                settings.default_session.user = mkDefault "greeter";
              };
              gvfs = {
                enable = mkDefault true;
                package = mkDefault pkgs.gnome.gvfs;
              };
              iio-niri.enable = mkDefault true;
              kmscon = {
                enable = mkDefault true;
                config = {
                  hwaccel = mkDefault true;
                };
              };
              libinput.enable = mkDefault true;
              packagekit.backends.nix-profile = {
                appstream.enable = mkDefault true;
                enable = mkDefault true;
              };
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
              power-profiles-daemon.enable = mkDefault true;
              printing = {
                enable = mkDefault true;
                browsed.enable = mkDefault true;
                webInterface = mkDefault false;
              };
              samba-wsdd.discovery = mkDefault true;
              system-config-printer.enable = mkDefault true;
              udev.packages = with pkgs; [ gnome-settings-daemon ];
              udisks2.enable = mkDefault true;
              upower.enable = mkDefault true;
            };

            services.openssh = mkIf cfg.enableSsh {
              enable = true;
              settings = {
                PermitRootLogin = cfg.sshRootLogin;
                PasswordAuthentication = cfg.sshPasswordAuth;
              };
            };

            security = {
              polkit.enable = mkDefault true;
              pam.services = {
                login.enableGnomeKeyring = mkDefault true;
                greetd.enableGnomeKeyring = mkDefault true;
              };
              rtkit.enable = mkDefault true;
              tpm2.enable = mkDefault true;
            };

            systemd = {
              packages = [ pkgs.niri ];
              services = {
                cups-browsed-resume = {
                  description = "Restart cups-browsed after resume from suspend";
                  after = [
                    "suspend.target"
                    "hibernate.target"
                    "hybrid-sleep.target"
                  ];
                  wantedBy = [
                    "suspend.target"
                    "hibernate.target"
                    "hybrid-sleep.target"
                  ];
                  serviceConfig = {
                    Type = "oneshot";
                    ExecStart = "systemctl restart cups-browsed";
                  };
                };
                system-upgrade = {
                  restartIfChanged = false;
                  unitConfig = {
                    Description = "Update flake inputs and switch NixOS configuration";
                    StartLimitIntervalSec = 300;
                    StartLimitBurst = 5;
                  };
                  serviceConfig = {
                    Type = "oneshot";
                    User = "root";
                    Environment = "HOME=/root";
                    # Skip gracefully (result=condition, no restart) when on a metered connection
                    ExecCondition = pkgs.writeShellScript "check-not-metered" ''
                      if ${pkgs.networkmanager}/bin/nmcli -g GENERAL.METERED dev show 2>/dev/null | grep -qi "yes"; then
                        echo "Network connection is metered, skipping system upgrade" >&2
                        exit 1
                      fi
                    '';
                    ExecStart = lib.getExe systemUpgradeScript;
                    Restart = "on-failure";
                    RestartSec = "120s";
                  };
                  wants = [ "network-online.target" ];
                  after = [ "network-online.target" ];
                  path = with pkgs; [
                    nix
                    git
                    networkmanager
                  ];
                };
                greetd.serviceConfig = {
                  Type = "idle";
                  StandardInput = "tty";
                  StandardOutput = "tty";
                  StandardError = "journal";
                  TTYReset = true;
                  TTYVHangup = true;
                  TTYVTDisallocate = true;
                };
              };
              timers.system-upgrade = {
                wantedBy = [ "timers.target" ];
                timerConfig = {
                  OnCalendar = "hourly";
                  Persistent = true;
                  Unit = "system-upgrade.service";
                };
              };
              user = {
                services = {
                  pipewire = {
                    wantedBy = [ "niri.service" ];
                    before = [ "niri.service" ];
                  };

                  # Ensure wireplumber waits for UPower to avoid battery query warnings
                  wireplumber = {
                    wants = [ "upower.service" ];
                    after = [ "upower.service" ];
                  };

                  # XDG Desktop Portal services - ensure they start after graphical session
                  # This prevents "cannot open display" errors during greeter/early boot
                  xdg-desktop-portal = {
                    after = [ "graphical-session.target" ];
                    partOf = [ "graphical-session.target" ];
                    # GLib validates desktop file Exec fields against PATH when looking
                    # up MIME handlers. Without system PATH, the portal discards all
                    # app candidates and shows "No Apps Available".
                    path = [ config.system.path ];
                  };
                  xdg-desktop-portal-gtk = {
                    after = [ "graphical-session.target" ];
                    partOf = [ "graphical-session.target" ];
                    path = [ config.system.path ];
                    serviceConfig = {
                      # Prevent rapid restart loops if display isn't ready
                      RestartSec = 2;
                      Restart = "on-failure";
                      RestartMaxDelaySec = 30;
                    };
                  };
                  xdg-desktop-portal-gnome = {
                    after = [
                      "graphical-session.target"
                      "xdg-desktop-portal-gtk.service"
                    ];
                    partOf = [ "graphical-session.target" ];
                    path = [ config.system.path ];
                  };

                  # User profile upgrade service
                  nix-profile-upgrade = {
                    description = "Upgrade user nix profile";
                    serviceConfig = {
                      Type = "oneshot";
                      ExecStart = "${pkgs.nix}/bin/nix profile upgrade --all";
                      Restart = "on-failure";
                      RestartSec = "120s";
                    };
                    wants = [ "network-online.target" ];
                    after = [ "network-online.target" ];
                    path = with pkgs; [
                      nix
                      git
                    ];
                  };

                  #   # DMS writes qt6ct.conf with a KDE-format .colors path that qt6ct
                  #   # can't parse. This service fires (via path unit below) whenever DMS
                  #   # overwrites the file and corrects color_scheme_path to the native
                  #   # qt6ct format file that matugen generates alongside the KDE one.
                  #   qt6ct-colorscheme-fix = {
                  #     description = "Correct qt6ct color_scheme_path to native format after DMS update";
                  #     serviceConfig = {
                  #       Type = "oneshot";
                  #       ExecStart = pkgs.writeShellScript "qt6ct-fix-colorscheme" ''
                  #         conf="$HOME/.config/qt6ct/qt6ct.conf"
                  #         native="$HOME/.config/qt6ct/colors/matugen.conf"
                  #         [ -f "$conf" ] && [ -f "$native" ] || exit 0
                  #         grep -qF "color_scheme_path=$native" "$conf" && exit 0
                  #         ${pkgs.gnused}/bin/sed -i "s|^color_scheme_path=.*|color_scheme_path=$native|" "$conf"
                  #       '';
                  #     };
                  #   };
                };

                # paths.qt6ct-colorscheme-fix = {
                #   description = "Watch qt6ct.conf for DMS color scheme overwrites";
                #   wantedBy = [ "graphical-session.target" ];
                #   pathConfig.PathModified = "%h/.config/qt6ct/qt6ct.conf";
                # };

                timers = {
                  nix-profile-upgrade = {
                    description = "Upgrade user nix profile timer";
                    wantedBy = [ "timers.target" ];
                    timerConfig = {
                      OnCalendar = "hourly";
                      Persistent = true;
                      Unit = "nix-profile-upgrade.service";
                    };
                  };
                };
              };
            };

            system.autoUpgrade.enable = mkDefault false;

            # Install user niri config to ~/.config/niri/config.kdl
            system.activationScripts.niriUserConfig = ''
              USER_HOME="/home/${cfg.username}"
              NIRI_CONFIG_DIR="$USER_HOME/.config/niri"
              DMS_DIR="$NIRI_CONFIG_DIR/dms"

              if [ -d "$USER_HOME" ]; then
              mkdir -p "$NIRI_CONFIG_DIR" "$DMS_DIR"

              # Always update config.kdl from the nix store
              cp ${./configs/niri-home.kdl} "$NIRI_CONFIG_DIR/config.kdl"

              # Create custom.kdl only if it doesn't exist (user's personal overrides)
              [ -f "$NIRI_CONFIG_DIR/custom.kdl" ] || touch "$NIRI_CONFIG_DIR/custom.kdl"
                
              # Ensure DMS config files exist (even as empty files)
              DMS_FILES=("alttab" "binds" "colors" "cursor" "layout" "outputs" "windowrules" "wpblur")
              for f in "''${DMS_FILES[@]}"; do
                [ -f "$DMS_DIR/$f.kdl" ] || touch "$DMS_DIR/$f.kdl"
              done

              chown -R ${cfg.username}:users "$USER_HOME/.config"
              fi
            '';

            system.stateVersion = cfg.stateVersion;

            time.timeZone = cfg.timeZone;

            i18n.defaultLocale = cfg.locale;

            users = {
              defaultUserShell = pkgs.nushell;
              users.${cfg.username} = {
                extraGroups = [
                  "input"
                  "networkmanager"
                  "wheel"
                ];
                initialPassword = cfg.initialPassword;
                isNormalUser = true;
                useDefaultShell = true;
              };
            };

            xdg = {
              autostart.enable = mkDefault true;
              icons = {
                enable = mkDefault true;
                fallbackCursorThemes = [ "Adwaita" ];
              };
              menus.enable = mkDefault true;
              mime = {
                enable = mkDefault true;
                defaultApplications = {
                  # Images → Loupe
                  "image/jpeg" = "org.gnome.Loupe.desktop";
                  "image/png" = "org.gnome.Loupe.desktop";
                  "image/gif" = "org.gnome.Loupe.desktop";
                  "image/webp" = "org.gnome.Loupe.desktop";
                  "image/tiff" = "org.gnome.Loupe.desktop";
                  "image/bmp" = "org.gnome.Loupe.desktop";
                  "image/x-bmp" = "org.gnome.Loupe.desktop";
                  "image/svg+xml" = "org.gnome.Loupe.desktop";
                  "image/avif" = "org.gnome.Loupe.desktop";
                  "image/heic" = "org.gnome.Loupe.desktop";
                  "image/heif" = "org.gnome.Loupe.desktop";
                  "image/jxl" = "org.gnome.Loupe.desktop";
                  "image/vnd.microsoft.icon" = "org.gnome.Loupe.desktop";
                  "image/x-portable-bitmap" = "org.gnome.Loupe.desktop";
                  "image/x-portable-pixmap" = "org.gnome.Loupe.desktop";
                  "image/x-portable-graymap" = "org.gnome.Loupe.desktop";
                  "image/x-portable-anymap" = "org.gnome.Loupe.desktop";
                  "image/x-tga" = "org.gnome.Loupe.desktop";
                  # Audio → Decibels
                  "audio/mpeg" = "org.gnome.Decibels.desktop";
                  "audio/mp3" = "org.gnome.Decibels.desktop";
                  "audio/ogg" = "org.gnome.Decibels.desktop";
                  "audio/x-ogg" = "org.gnome.Decibels.desktop";
                  "audio/vorbis" = "org.gnome.Decibels.desktop";
                  "audio/flac" = "org.gnome.Decibels.desktop";
                  "audio/x-flac" = "org.gnome.Decibels.desktop";
                  "audio/wav" = "org.gnome.Decibels.desktop";
                  "audio/x-wav" = "org.gnome.Decibels.desktop";
                  "audio/aac" = "org.gnome.Decibels.desktop";
                  "audio/mp4" = "org.gnome.Decibels.desktop";
                  "audio/x-m4a" = "org.gnome.Decibels.desktop";
                  "audio/opus" = "org.gnome.Decibels.desktop";
                  # Video → Showtime
                  "video/mp4" = "org.gnome.Showtime.desktop";
                  "video/x-matroska" = "org.gnome.Showtime.desktop";
                  "video/webm" = "org.gnome.Showtime.desktop";
                  "video/ogg" = "org.gnome.Showtime.desktop";
                  "video/mpeg" = "org.gnome.Showtime.desktop";
                  "video/quicktime" = "org.gnome.Showtime.desktop";
                  "video/x-msvideo" = "org.gnome.Showtime.desktop";
                  "video/x-flv" = "org.gnome.Showtime.desktop";
                  "video/x-ms-wmv" = "org.gnome.Showtime.desktop";
                  "video/3gpp" = "org.gnome.Showtime.desktop";
                  "video/3gpp2" = "org.gnome.Showtime.desktop";
                  "video/x-ogm+ogg" = "org.gnome.Showtime.desktop";
                  # Documents → Papers
                  "application/pdf" = "org.gnome.Papers.desktop";
                  "application/epub+zip" = "org.gnome.Papers.desktop";
                  "application/x-cbr" = "org.gnome.Papers.desktop";
                  "application/x-cbz" = "org.gnome.Papers.desktop";
                  "application/x-cb7" = "org.gnome.Papers.desktop";
                  "application/x-cbt" = "org.gnome.Papers.desktop";
                  # Directories → Nautilus
                  "inode/directory" = "org.gnome.Nautilus.desktop";
                };
              };
              portal = {
                enable = mkDefault true;
                configPackages = mkDefault (
                  with pkgs;
                  [
                    gnome-keyring
                    niri
                  ]
                );
                extraPortals = mkDefault (
                  with pkgs;
                  [
                    gnome-keyring
                    xdg-desktop-portal-gnome
                    xdg-desktop-portal-gtk
                  ]
                );
                xdgOpenUsePortal = mkDefault false;
                config = {
                  common = {
                    default = [
                      "gnome"
                      "kde"
                      "gtk"
                    ];
                    "org.freedesktop.impl.portal.Access" = "gtk";
                    "org.freedesktop.impl.portal.FileChooser" = "gtk";
                    "org.freedesktop.impl.portal.Notification" = "gtk";
                    "org.freedesktop.impl.portal.OpenURI" = "gtk";
                    "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
                    "org.freedesktop.impl.portal.Settings" = "gnome";
                  };
                };
              };
              sounds.enable = mkDefault true;
              terminal-exec = {
                enable = mkDefault true;
                settings = {
                  default = [ "ghostty.desktop" ];
                };
              };
            };

            zramSwap.enable = mkDefault true;
          };
        };
    };
}
