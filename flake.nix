{
  description = "NixOS Micro Desktop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-profile-backend = {
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
        in
        {
          imports = [
            inputs.disko.nixosModules.disko
            inputs.nix-profile-backend.nixosModules.default
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
              kernelPackages = mkDefault pkgs.linuxPackages_zen;
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
              ];
              plymouth.enable = mkDefault true;
            };

            console = {
              keyMap = mkDefault "us";
              packages = mkDefault [ pkgs.terminus_font ];
            };

            disko.devices = {
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
              };
              pathsToLink = [
                "/share/app-info"
                "/share/applications"
                "/share/icons"
                "/share/metainfo"
                "/share/pixmaps"
                "/share/thumbnailers"
                "/share/xdg-desktop-portal"
              ];
              variables = {
                CLUTTER_BACKEND = "wayland";
                EGL_PLATFORM = "wayland";
                ELECTRON_OZONE_PLATFORM_HINT = "wayland";
                GDK_BACKEND = "wayland";
                GDK_PLATFORM = "wayland";
                GTK_BACKEND = "wayland";
                MOZ_ENABLE_WAYLAND = "1";
                NIXPKGS_ALLOW_UNFREE = "1";
                OCL_ICD_VENDORS = "/run/opengl-driver/etc/OpenCL/vendors";
                PROTOC = "${pkgs.protobuf}/bin/protoc";
                QML_DISABLE_DISK_CACHE = "1";
                QSG_RHI_BACKEND = "vulkan";
                QT_QPA_PLATFORM = "wayland";
                # QT_QPA_PLATFORMTHEME = "gtk3";
                QT_SCALE_FACTOR_ROUNDING_POLICY = "RoundPreferFloor";
                # QT_STYLE_OVERRIDE = "adwaita-dark";
                SAL_ENABLESKIA = "1";
                SAL_FORCESKIA = "1";
                SAL_SKIA = "vulkan";
                SDL_VIDEODRIVER = "wayland";
				TERMINAL = "alacritty";
                XDG_CURRENT_DESKTOP = "niri";
                XDG_SESSION_DESKTOP = "niri";
                XDG_SESSION_TYPE = "wayland";
              };
              systemPackages =
                with pkgs;
                lib.flatten [
                  [
                    (writeShellScriptBin "dms-ipc" (builtins.readFile ./scripts/dms-ipc))
                    adwaita-icon-theme
                    adwaita-qt
                    adwaita-qt6
                    adw-gtk3
                    alacritty
                    brightnessctl
                    cava
                    cliphist
                    dnsmasq
                    dsearch
                    ffmpeg-headless
                    ffmpegthumbnailer
                    fprintd
                    gammastep
                    gcr_4
                    gdk-pixbuf
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
                    key-rack
                    libdbusmenu
                    libheif
                    libheif.out
                    libsecret
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
                    polkit
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
                    xwayland-satellite
                  ]
                  cfg.extraPackages
                ];
              sessionVariables = {
                NIXOS_OZONE_WL = "1";
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
              powertop.enable = mkDefault true;
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
                extraBackends = mkDefault (with pkgs; [ sane-airscan ]);
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
              };
            };

            nixpkgs.config = {
              allowBroken = true;
              allowUnfree = true;
              allowUnfreePredicate = _: true;
            };

            programs = {
              appimage.enable = mkDefault true;
              dconf.enable = mkDefault true;

              # DMS Shell (nixpkgs native)
              dms-shell = {
                enable = mkDefault true;
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
              niri.enable = mkDefault true;
              uwsm = {
                enable = mkDefault true;
                waylandCompositors.niri = {
                  prettyName = "Niri";
                  comment = "A scrollable-tiling Wayland compositor";
                  binPath = getExe pkgs.niri;
                  extraArgs = [ "--session" ];
                };
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
              platformTheme = "gnome";
              style = "adwaita-dark";
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
              bpftune.enable = true;
              colord.enable = mkDefault true;
              dbus = {
                implementation = mkDefault "broker";
                packages = with pkgs; [
                  dconf
                  gcr
                  libdbusmenu
                  lxqt.libdbusmenu-lxqt
                  nautilus
                ];
              };
              displayManager = {
                defaultSession = "niri-uwsm";
                dms-greeter = {
                  enable = mkDefault true;
                  compositor.name = "niri";
                };
              };
              fprintd.enable = mkDefault true;
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
                enable = true;
                hwRender = true;
              };
              libinput.enable = mkDefault true;
              packagekit.backends.nix-profile = {
                appstream.enable = true;
                enable = true;
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
                swaylock = { };
              };
              rtkit.enable = mkDefault true;
              tpm2.enable = mkDefault true;
            };

            systemd = {
              packages = [ pkgs.niri ];
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
                  StandardError = "journal";
                  TTYReset = true;
                  TTYVHangup = true;
                  TTYVTDisallocate = true;
                };
              };
              timers.flake-update = {
                wantedBy = [ "timers.target" ];
                timerConfig = {
                  OnCalendar = "hourly";
                  Persistent = true;
                  Unit = "flake-update.service";
                };
              };
              user.services = {
                pipewire = {
                  wantedBy = [ "wayland-session@niri.target" ];
                  before = [ "wayland-session@niri.target" ];
                };

                # Ensure wireplumber waits for UPower to avoid battery query warnings
                wireplumber = {
                  wants = [ "upower.service" ];
                  after = [ "upower.service" ];
                };

                # GNOME Keyring daemon (secrets and pkcs11 only; SSH handled by gcr-ssh-agent)
                gnome-keyring = {
                  description = "GNOME Keyring daemon";
                  wantedBy = [ "graphical-session-pre.target" ];
                  partOf = [ "graphical-session-pre.target" ];
                  serviceConfig = {
                    Type = "simple";
                    ExecStart = "/run/wrappers/bin/gnome-keyring-daemon --start --foreground --components=secrets,pkcs11";
                    Restart = "on-failure";
                  };
                };

                # Polkit authentication agent
                niri-polkit = {
                  description = "PolicyKit Authentication Agent for niri";
                  wantedBy = [ "graphical-session.target" ];
                  after = [ "graphical-session.target" ];
                  partOf = [ "graphical-session.target" ];
                  serviceConfig = {
                    Type = "simple";
                    ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
                    Restart = "on-failure";
                    RestartSec = 1;
                    TimeoutStopSec = 10;
                  };
                };

                # Swayidle for auto-suspend
                swayidle = {
                  description = "Idle manager for niri";
                  wantedBy = [ "graphical-session.target" ];
                  after = [ "graphical-session.target" ];
                  partOf = [ "graphical-session.target" ];
                  serviceConfig = {
                    Type = "simple";
                    ExecStart = "${pkgs.swayidle}/bin/swayidle -w timeout 600 '${pkgs.systemd}/bin/systemctl suspend'";
                    Restart = "on-failure";
                  };
                };
              };
            };

            system.autoUpgrade = {
              allowReboot = mkDefault false;
              enable = mkDefault true;
              flake = mkDefault "/etc/nixos";
            };

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
              DMS_FILES=("alttab" "binds" "colors" "cursor" "layout" "outputs" "wpblur")
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
              defaultUserShell = pkgs.bashInteractive;
              users.${cfg.username} = {
                extraGroups = [
                  "input"
                  "networkmanager"
                  "wheel"
                ];
                initialPassword = cfg.initialPassword;
                isNormalUser = true;
              };
            };

            xdg = {
              autostart.enable = mkDefault true;
              icons = {
                enable = mkDefault true;
                fallbackCursorThemes = [ "Adwaita" ];
              };
              menus.enable = mkDefault true;
              mime.enable = mkDefault true;
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
                xdgOpenUsePortal = mkDefault true;
                config = {
                  common = {
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
    };
}
