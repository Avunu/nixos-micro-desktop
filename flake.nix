{
  description = "NixOS Micro Desktop";

  inputs = {
    disko = {
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:nix-community/disko";
    };
    # niri-flake builds niri itself rather than relying on nixpkgs' in-tree
    # package (currently broken upstream) or the official niri flake (also
    # fails to build at the moment). It publishes pre-built niri-stable /
    # niri-unstable to the niri.cachix.org binary cache, which
    # nixosModules.niri wires up automatically.
    niri = {
      # inputs = {
      #   nixpkgs.follows = "nixpkgs";
      # };
      url = "github:sodiboo/niri-flake";
    };
    nix-packagekit = {
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:Avunu/nix-profile-packagekit-backend";
    };
    nixos-install-helper = {
      inputs = {
        disko.follows = "disko";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:Avunu/nixos-install-helper";
    };
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };
  };

  outputs =
    { nixpkgs, self, ... }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";

      # Public-facing installer: derives its menu from microDesktop.* and ships
      # unattended / guided ISOs plus a nixos-anywhere deploy. The whole
      # installer surface is this one call.
      ih = inputs.nixos-install-helper.lib.mkProject {
        diskName = "main";
        flakeStyle = "local";
        hints = {
          diskDevice = "disk-device";
        };
        installModules = [ self.nixosModules.microDesktop ];
        inherit nixpkgs self system;
        optionRoots = [ "microDesktop" ];
        upstream = "github:Avunu/nixos-micro-desktop";
      };
    in
    {
      # ── Installer (via nixos-install-helper) ─────────────────────────────────
      # install / installTemplate systems, the unattended + guided ISOs, and the
      # configure / install / deploy apps — all derived from microDesktop.*.
      apps = ih.apps;

      devShells = {
        x86_64-linux = {
          default =
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
        };
      };

      nixosConfigurations = ih.nixosConfigurations;

      nixosModules = {
        microDesktop =
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
                coreutils
                git
                nix
                nixos-rebuild
              ];
              text = ''
                if [ "$(id -u)" -ne 0 ]; then
                  exec /run/wrappers/bin/pkexec "$0" "$@"
                fi

                LOCK_FILE="/etc/nixos/flake.lock"
                BEFORE=""
                if [ -f "$LOCK_FILE" ]; then
                  BEFORE=$(sha256sum "$LOCK_FILE")
                fi

                ${lib.getExe pkgs.nix} flake update --flake /etc/nixos

                AFTER=""
                if [ -f "$LOCK_FILE" ]; then
                  AFTER=$(sha256sum "$LOCK_FILE")
                fi

                if [ "$BEFORE" != "$AFTER" ]; then
                  ${lib.getExe pkgs.nixos-rebuild} switch --flake /etc/nixos
                else
                  echo "Flake lock unchanged, skipping rebuild" >&2
                fi
              '';
            };

            # Fcitx5 classicui theme (Material dark) for the clipboard/unicode
            # pickers. classicui has no corner-radius field — rounded corners
            # require 9-sliced background images — so the SVG sources under
            # ./configs/fcitx5/theme are rendered to PNG at build time (classicui
            # loads PNG via cairo). Installed to share/fcitx5/themes/micro-material
            # (linked onto XDG_DATA_DIRS via pathsToLink "/share/fcitx5") and
            # selected by the classicui Theme= setting below.
            microFcitx5Theme = pkgs.runCommand "micro-fcitx5-theme" { nativeBuildInputs = [ pkgs.librsvg ]; } ''
              dst=$out/share/fcitx5/themes/micro-material
              mkdir -p "$dst"
              cp ${./configs/fcitx5/theme/micro-material/theme.conf} "$dst/theme.conf"
              rsvg-convert -o "$dst/panel.png"     ${./configs/fcitx5/theme/micro-material/panel.svg}
              rsvg-convert -o "$dst/highlight.png" ${./configs/fcitx5/theme/micro-material/highlight.svg}
            '';
          in
          {
            config = {
              boot = {
                consoleLogLevel = mkDefault 0;
                initrd = {
                  availableKernelModules = [
                    "ahci"
                    "ehci_pci"
                    "nvme"
                    "uhci_hcd"
                  ];
                  # fbcon is built into the kernel (not a loadable module), so it
                  # must not be listed here — doing so breaks the modules-shrunk
                  # initrd build. The framebuffer console is configured via the
                  # `fbcon=vc:2-6` kernel parameter below.
                  systemd = {
                    enable = mkDefault true;
                    tpm2.enable = mkDefault true;
                  };
                  verbose = mkDefault false;
                };
                kernel = {
                  sysctl = {
                    "vm.dirty_background_ratio" = mkDefault 5; # Start background writeback early
                    "vm.dirty_ratio" = mkDefault 10; # default; elevated values increase unreclaimable memory pressure
                    # Single-page swap reads (optimal for zram).  If a disk swap file is
                    # present (e.g. via devWorkstation.extraConfig), this makes disk swap
                    # extremely slow — acceptable only as a last-resort safety net.
                    "vm.page-cluster" = mkDefault 0;
                    "vm.swappiness" = mkDefault 100; # zram benefits from eager compression; 100 avoids OOM before zram fills
                    "vm.vfs_cache_pressure" = mkDefault 50; # Keep inodes/dentries cached longer for SQLite
                  };
                };
                kernelPackages = mkDefault pkgs.linuxPackages_latest;
                kernelParams = [
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
                loader = mkMerge [
                  (mkIf (cfg.bootMode == "uefi") {
                    efi = {
                      canTouchEfiVariables = mkDefault true;
                    };
                    systemd-boot = {
                      configurationLimit = mkDefault 10;
                      enable = mkDefault true;
                    };
                  })
                  (mkIf (cfg.bootMode == "legacy") {
                    grub = {
                      enable = mkDefault true;
                    };
                  })
                  ({ timeout = mkDefault 2; })
                ];
                plymouth = {
                  enable = mkDefault true;
                };
                supportedFilesystems = {
                  ext3 = mkDefault false;
                  ntfs3 = mkDefault false;
                  xfs = mkDefault false;
                  zfs = mkDefault false;
                };
                swraid = {
                  enable = mkDefault false;
                };
                tmp = {
                  cleanOnBoot = mkDefault true;
                  useTmpfs = mkDefault false;
                };
              };

              console = {
                keyMap = mkDefault "us";
                packages = [ pkgs.terminus_font ];
              };

              disko = {
                devices = mkDefault {
                  disk = {
                    main = {
                      content = mkMerge [
                        (mkIf (cfg.bootMode == "uefi") {
                          partitions = {
                            ESP = {
                              content = {
                                extraArgs = [
                                  "-n"
                                  "ESP"
                                ];
                                format = "vfat";
                                mountOptions = [
                                  "noatime"
                                  "umask=0077"
                                ];
                                mountpoint = "/boot";
                                type = "filesystem";
                              };
                              size = "1G";
                              type = "EF00";
                            };
                            root = {
                              content = {
                                extraArgs = [
                                  "-O"
                                  "extra_attr,compression" # Enable compression feature at format time
                                  "-l"
                                  "root"
                                ];
                                format = "f2fs";
                                mountOptions = [
                                  "atgc"
                                  "compress_algorithm=zstd:1" # Level 1: minimal CPU overhead, reduces I/O bandwidth
                                  "compress_cache" # Cache decompressed pages for hot data (SQLite, desktop apps)
                                  "compress_chksum"
                                  "compress_extension=*" # Compress all files by default
                                  # ...except frequently-rewritten small WAL/journal/lock files: recompressing
                                  # a whole cluster on every tiny in-place-ish rewrite (SQLite/LevelDB WAL,
                                  # systemd journal) is a known GC/checkpoint stall pattern under f2fs, worst
                                  # when the volume is mostly full. See linux-f2fs-devel deadlock reports.
                                  # f2fs mount options are comma-split at the top level, so each excluded
                                  # extension needs its own repeated nocompress_extension=... entry — a single
                                  # comma-joined value gets torn into unrecognized tokens and fails root mount.
                                  # Each extension is also capped at 7 chars (F2FS_EXTENSION_LEN=8 incl. NUL) —
                                  # "sqlite-wal"/"sqlite-shm" (10 chars) overflow that and get rejected with
                                  # "invalid extension length/number", failing the mount entirely. Omitted below;
                                  # rely on the shorter db-wal/db-shm convention instead.
                                  "nocompress_extension=db"
                                  "nocompress_extension=db-wal"
                                  "nocompress_extension=db-shm"
                                  "nocompress_extension=sqlite"
                                  "nocompress_extension=ldb"
                                  "nocompress_extension=log"
                                  "nocompress_extension=journal"
                                  "nocompress_extension=lock"
                                  "gc_merge"
                                  "noatime"
                                  "nodiscard" # Use scheduled fstrim instead of synchronous discard
                                ];
                                mountpoint = "/";
                                type = "filesystem";
                              };
                              size = "100%";
                            };
                          };
                          type = "gpt";
                        })
                        (mkIf (cfg.bootMode == "legacy") {
                          partitions = {
                            boot = {
                              size = "1M";
                              type = "EF02";
                            };
                            root = {
                              content = {
                                extraArgs = [
                                  "-O"
                                  "extra_attr,compression" # Enable compression feature at format time
                                  "-l"
                                  "root"
                                ];
                                format = "f2fs";
                                mountOptions = [
                                  "atgc"
                                  "compress_algorithm=zstd:1" # Level 1: minimal CPU overhead, reduces I/O bandwidth
                                  "compress_cache" # Cache decompressed pages for hot data (SQLite, desktop apps)
                                  "compress_chksum"
                                  # "compress_extension=*" # Compress all files by default
                                  "gc_merge"
                                  "noatime"
                                  "nodiscard" # Use scheduled fstrim instead of synchronous discard
                                ];
                                mountpoint = "/";
                                type = "filesystem";
                              };
                              size = "100%";
                            };
                          };
                          type = "gpt";
                        })
                      ];
                      device = cfg.diskDevice;
                      type = "disk";
                    };
                  };
                };
              };

              documentation = {
                doc = {
                  enable = mkDefault false;
                };
                enable = mkDefault false;
                man = {
                  enable = mkDefault false;
                };
                nixos = {
                  enable = mkDefault false;
                };
              };

              environment = {
                etc = {
                  # Fix Electron CHROME_DESKTOP on NixOS: preload script that derives
                  # the correct .desktop name from process.argv at JS init time.
                  "environment.d/60-electron-chrome-desktop.conf" = {
                    text = ''
                      NODE_OPTIONS="--require=${./scripts/electron-chrome-desktop-fix.js}"
                    '';
                  };
                  # deploy default GTK config
                  "gtk-3.0/settings.ini" = {
                    source = ./configs/gtk-3.0-settings.ini;
                  };
                  "gtk-4.0/settings.ini" = {
                    source = ./configs/gtk-4.0-settings.ini;
                  };
                  # Deploy niri config system-wide
                  "niri/config.kdl" = {
                    source = ./configs/niri-global.kdl;
                  };
                  "nix/nixpkgs-config.nix" = {
                    text = lib.mkDefault ''
                      {
                        allowUnfree = true;
                      }
                    '';
                  };
                  # "xdg/menus/applications.menu".source =
                  #   "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
                  # "xdg/qt6ct/qt6ct.conf".source = ./configs/qt6ct.conf;
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
                  # fcitx5 classicui themes (micro-material) resolve via
                  # XDG_DATA_DIRS/fcitx5/themes — link the fcitx5 data dir so the
                  # fcitx5 user service finds the theme.
                  "/share/fcitx5"
                ];
                sessionVariables = {
                  # Curated XDG_DATA_DIRS to prevent duplicate D-Bus service warnings
                  # Only include paths that are actually needed:
                  # - User's local share (for local .desktop files)
                  # - User's nix-profile (for nix profile installed packages)
                  # - Display manager session data (for .desktop session files)
                  # - System path (canonical aggregation of all system packages)
                  # Using mkDefault so other modules (nix-packagekit, display-managers) can extend.
                  XDG_DATA_DIRS = mkDefault "$HOME/.local/share:$HOME/.nix-profile/share:${config.services.displayManager.sessionData.desktops}/share:/run/current-system/sw/share";
                };
                shells = with pkgs; [
                  bash
                  nushell
                ];
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
                      gst_all_1.gstreamer
                      gtk4.out
                      key-rack
                      libdbusmenu
                      libheif
                      libheif.out
                      libmtp
                      libsecret
                      loupe
                      lxqt.libdbusmenu-lxqt
                      matugen
                      # Classicui theme for the fcitx5 clipboard/emoji pickers
                      # (i18n.inputMethod adds fcitx5-with-addons itself).
                      microFcitx5Theme
                      mission-center
                      morewaita-icon-theme
                      nautilus
                      packagekit
                      papers
                      playerctl
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
                variables = {
                  CLUTTER_BACKEND = "wayland";
                  EGL_PLATFORM = "wayland";
                  ELECTRON_OZONE_PLATFORM_HINT = "wayland";
                  GDK_BACKEND = "wayland";
                  GDK_PLATFORM = "wayland";
                  GTK_BACKEND = "wayland";
                  # GTK_THEME = "adw-gtk";
                  MOZ_ENABLE_WAYLAND = "1";
                  MU_QT_QPA_PLATFORM = "wayland";
                  NIXPKGS_ALLOW_UNFREE = "1";
                  OCL_ICD_VENDORS = "/run/opengl-driver/etc/OpenCL/vendors";
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
                  # SQLite performance: use /tmp (tmpfs) for temp files instead of f2fs
                  SQLITE_TMPDIR = "/tmp";
                  TERMINAL = getExe pkgs.ghostty;
                  XDG_CURRENT_DESKTOP = "niri";
                  XDG_SESSION_DESKTOP = "niri";
                  XDG_SESSION_TYPE = "wayland";
                };
              };

              fileSystems = {
                "/" = {
                  # disable fsck with f2fs until it runs correctly with the large amount of /nix symlinks
                  noCheck = mkDefault true;
                };
              };

              fonts = {
                enableDefaultPackages = mkForce false;
                fontDir = {
                  enable = mkDefault true;
                };
                fontconfig = {
                  defaultFonts = {
                    emoji = [
                      "Noto Color Emoji"
                      "Noto Emoji"
                    ];
                    monospace = [
                      "Adwaita Mono"
                      "Cascadia Code"
                      "Liberation Mono"
                    ];
                    sansSerif = [
                      "Adwaita Sans"
                      "Inter"
                      "Liberation Sans"
                    ];
                    serif = [
                      "Liberation Serif"
                      "DejaVu Serif"
                    ];
                  };
                  enable = true;
                };
                packages = with pkgs; [
                  # Modern GNOME fonts
                  adwaita-fonts

                  # Essential font families
                  dejavu_fonts
                  freefont_ttf
                  gyre-fonts
                  liberation_ttf
                  noto-fonts
                  noto-fonts-cjk-sans
                  noto-fonts-cjk-serif
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
                ];
              };

              gtk = {
                iconCache = {
                  enable = mkDefault true;
                };
              };

              hardware = {
                bluetooth = {
                  enable = mkDefault true;
                };
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
                  extraBackends = with pkgs; [
                    sane-airscan
                    sane-backends
                  ];
                };
                sensor = {
                  iio = {
                    enable = mkDefault true;
                  };
                };
              };

              i18n = {
                defaultLocale = cfg.locale;
                # Fcitx5 as a clipboard-history (Super+V) + unicode/emoji (Super+.)
                # picker — NOT for CJK text input. The only input method is the
                # built-in keyboard-us group; every IM-switching hotkey is disabled
                # in globalOptions so fcitx doesn't grab Ctrl+Space / Super+Space.
                # The pickers commit at the text caret over the Wayland input-method
                # protocol (waylandFrontend), so their triggers must reach the app —
                # niri must NOT bind Super+V / Super+. (see configs/niri-global.kdl).
                #
                # Config is generated by the core module: settings.globalOptions →
                # /etc/xdg/fcitx5/config, settings.addons.<name> →
                # /etc/xdg/fcitx5/conf/<name>.conf. Booleans are written as the
                # capitalized strings fcitx expects ("True"/"False"); an empty
                # attrset renders a bare section header (= empty list override).
                inputMethod = {
                  enable = mkDefault true;
                  fcitx5 = {
                    settings = {
                      addons = {
                        # Candidate window styling; selects the micro-material theme.
                        classicui = {
                          globalSection = {
                            DarkTheme = "micro-material";
                            Font = "Inter 11";
                            MenuFont = "Inter 11";
                            PerScreenDPI = "False";
                            Theme = "micro-material";
                            TrayFont = "Inter Bold 10";
                            "Vertical Candidate List" = "True";
                          };
                        };
                        # Windows-11-style Super+V clipboard history; picking an
                        # entry commits it through the input context (paste-at-cursor).
                        clipboard = {
                          globalSection = {
                            ClearPasswordAfter = 30;
                            IgnorePasswordFromPasswordManager = "True";
                            "Number of entries" = 30;
                            ShowPassword = "False";
                          };
                          sections = {
                            PastePrimaryKey = { }; # no paste-primary key
                            # Keysym MUST be uppercase V — fcitx normalizes letter
                            # keys to their uppercase keysym before matching.
                            TriggerKey = {
                              "0" = "Super+V";
                            };
                          };
                        };
                        # Super+. searches symbols/emoji by Unicode name (Win+. style).
                        unicode = {
                          globalSection = { };
                          sections = {
                            TriggerKey = {
                              "0" = "Super+period";
                            };
                          };
                        };
                        # Keep the virtual keyboard alive across focus changes to
                        # avoid re-pushing a keymap (xkbcomp journal spam) each time.
                        waylandim = {
                          globalSection = {
                            PersistentVirtualKeyboard = "True";
                          };
                        };
                      };
                      globalOptions = {
                        # Disable IM trigger / group-switch hotkeys (single IM only) —
                        # every "Hotkey/*Keys" entry below set to {} is disabled.
                        # Candidate nav for both pickers: Up/Down = prev/next candidate,
                        # Left/Right (+ Page_Up/Down) = paging.
                        Behavior = {
                          ShowInputMethodInformation = "False";
                        };
                        "Hotkey/ActivateKeys" = { };
                        "Hotkey/AltTriggerKeys" = { };
                        "Hotkey/DeactivateKeys" = { };
                        "Hotkey/EnumerateBackwardKeys" = { };
                        "Hotkey/EnumerateForwardKeys" = { };
                        "Hotkey/EnumerateGroupBackwardKeys" = { };
                        "Hotkey/EnumerateGroupForwardKeys" = { };
                        "Hotkey/NextCandidate" = {
                          "0" = "Down";
                        };
                        "Hotkey/NextPage" = {
                          "0" = "Right";
                          "1" = "Page_Down";
                        };
                        "Hotkey/PrevCandidate" = {
                          "0" = "Up";
                        };
                        "Hotkey/PrevPage" = {
                          "0" = "Left";
                          "1" = "Page_Up";
                        };
                        "Hotkey/TriggerKeys" = { };
                      };
                    };
                    # Wayland frontend: commit-at-caret via zwp_input_method_v2 and
                    # leave GTK_IM_MODULE/QT_IM_MODULE unset so normal typing is not
                    # routed through fcitx. clipboard/unicode/classicui/waylandim are
                    # all in base fcitx5-with-addons, so no extra addons are needed.
                    waylandFrontend = mkDefault true;
                  };
                  type = mkDefault "fcitx5";
                };
              };

              networking = {
                firewall = {
                  allowedTCPPorts = [
                    7236
                    7250
                  ];
                  allowedUDPPorts = [
                    7236
                    5353
                  ];
                  enable = mkDefault false;
                };
                hostName = cfg.hostName;
                networkmanager = {
                  enable = mkDefault true;
                  plugins = mkIf cfg.enableVpn (
                    with pkgs;
                    [
                      networkmanager-openvpn
                      networkmanager-vpnc
                      networkmanager-openconnect
                      networkmanager-l2tp
                    ]
                  );
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

              nixpkgs = {
                config = {
                  allowBroken = true;
                  allowUnfree = true;
                  allowUnfreePredicate = _: true;
                };
                overlays = [ inputs.niri.overlays.niri ];
              };

              powerManagement = {
                enable = mkDefault true;
                powertop = {
                  enable = mkDefault false;
                };
              };

              programs = {
                appimage = {
                  enable = mkDefault true;
                };
                dconf = {
                  enable = mkDefault true;
                };
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
                  config = {
                    safe = {
                      directory = [ "/etc/nixos" ];
                    };
                  };
                  enable = true;
                };
                gnupg = {
                  agent = {
                    enable = mkDefault true;
                    enableSSHSupport = mkDefault false; # Using gcr-ssh-agent for SSH
                    pinentryPackage = mkDefault pkgs.pinentry-gnome3;
                  };
                };
                # niri-flake disables nixpkgs' own programs.niri module (which
                # provided the niri-specific xdg-desktop-portal profile), so
                # file-chooser/notification portal backends now come from
                # xdg.portal.config.common below for niri sessions too.
                # Package defaults to niri-flake's niri-stable, served from
                # the niri.cachix.org binary cache (niri-flake.cache.enable,
                # on by default) — avoids building niri from source, which
                # currently fails both in nixpkgs and niri's own flake.
                niri = {
                  enable = mkDefault true;
                  package = pkgs.niri-unstable;
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
                    # vulkan-validation-layers
                    wayland
                    zstd
                  ];
                  package = pkgs.nix-ld;
                };
              };

              security = {
                pam = {
                  services = {
                    greetd = {
                      enableGnomeKeyring = mkDefault true;
                    };
                    login = {
                      enableGnomeKeyring = mkDefault true;
                    };
                  };
                };
                polkit = {
                  enable = mkDefault true;
                  enablePkexecWrapper = mkDefault true;
                };
                rtkit = {
                  enable = mkDefault true;
                };
                tpm2 = {
                  enable = mkDefault true;
                };
              };

              services = {
                accounts-daemon = {
                  enable = mkDefault true;
                };
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
                # bpftune dynamically overrides swappiness/watermarks at runtime,
                # which conflicts with zram tuning. Disabled until per-sysctl
                # exclusion is supported upstream.
                bpftune = {
                  enable = mkDefault false;
                };
                colord = {
                  enable = mkDefault true;
                };
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
                    compositor = {
                      name = "niri";
                    };
                    configHome = "/home/${cfg.username}";
                    enable = mkDefault true;
                  };
                  # niri-flake's module already adds programs.niri.package here.
                };
                fprintd = {
                  enable = mkDefault true;
                  package = mkDefault pkgs.fprintd-tod;
                  tod = {
                    driver = mkDefault pkgs.libfprint-2-tod1-goodix;
                    enable = mkDefault true;
                  };
                };
                fstrim = {
                  enable = mkDefault true;
                  interval = mkDefault "daily";
                };
                fwupd = {
                  enable = mkDefault true;
                };
                gnome = {
                  glib-networking = {
                    enable = mkDefault true;
                  };
                  gnome-keyring = {
                    enable = mkDefault true;
                  };
                  gnome-online-accounts = {
                    enable = mkDefault true;
                  };
                  gnome-settings-daemon = {
                    enable = mkDefault true;
                  };
                  localsearch = {
                    enable = mkDefault true;
                  };
                  sushi = {
                    enable = mkDefault true;
                  };
                  tinysparql = {
                    enable = mkDefault true;
                  };
                };
                greetd = {
                  enable = mkDefault true;
                  settings = {
                    default_session = {
                      user = mkDefault "greeter";
                    };
                  };
                };
                gvfs = {
                  enable = mkDefault true;
                  package = mkDefault pkgs.gnome.gvfs;
                };
                iio-niri = {
                  enable = mkDefault true;
                };
                kmscon = {
                  config = {
                    hwaccel = mkDefault true;
                  };
                  enable = mkDefault true;
                };
                libinput = {
                  enable = mkDefault true;
                };
                openssh = mkIf cfg.enableSsh {
                  enable = true;
                  settings = {
                    PasswordAuthentication = cfg.sshPasswordAuth;
                    PermitRootLogin = cfg.sshRootLogin;
                  };
                };
                packagekit = {
                  backends = {
                    nix-profile = {
                      appstream = {
                        enable = mkDefault true;
                      };
                      enable = mkDefault true;
                    };
                  };
                };
                pipewire = {
                  alsa = {
                    enable = mkDefault true;
                  };
                  enable = mkDefault true;
                  pulse = {
                    enable = mkDefault true;
                  };
                  wireplumber = {
                    enable = true;
                    extraConfig = {
                      "10-bluez" = {
                        monitor = {
                          bluez = {
                            properties = {
                              "bluez5.codecs" = [
                                "sbc"
                                "sbc_xq"
                                "aac"
                                "ldac"
                                "aptx"
                                "aptx_hd"
                              ];
                              "bluez5.enable-hw-volume" = true;
                              "bluez5.enable-msbc" = true;
                              "bluez5.enable-sbc-xq" = true;
                            };
                          };
                        };
                      };
                    };
                  };
                };
                power-profiles-daemon = {
                  enable = mkDefault true;
                };
                printing = {
                  browsed = {
                    enable = mkDefault true;
                  };
                  enable = mkDefault true;
                  webInterface = mkDefault false;
                };
                samba-wsdd = {
                  discovery = mkDefault true;
                };
                system-config-printer = {
                  enable = mkDefault true;
                };
                udev = {
                  packages = with pkgs; [ gnome-settings-daemon ];
                };
                udisks2 = {
                  enable = mkDefault true;
                };
                upower = {
                  enable = mkDefault true;
                };
              };

              system = {
                activationScripts = {
                  # Install user niri config to ~/.config/niri/config.kdl
                  niriUserConfig = ''
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
                };
                autoUpgrade = {
                  enable = mkDefault false;
                };
                stateVersion = cfg.stateVersion;
              };

              systemd = {
                # niri-flake's module doesn't register systemd.packages itself;
                # do it here so the niri.service unit exists (referenced by the
                # pipewire user service below).
                packages = [ config.programs.niri.package ];
                services = {
                  cups-browsed-resume = {
                    after = [
                      "suspend.target"
                      "hibernate.target"
                      "hybrid-sleep.target"
                    ];
                    description = "Restart cups-browsed after resume from suspend";
                    serviceConfig = {
                      ExecStart = "systemctl restart cups-browsed";
                      Type = "oneshot";
                    };
                    wantedBy = [
                      "suspend.target"
                      "hibernate.target"
                      "hybrid-sleep.target"
                    ];
                  };
                  greetd = {
                    serviceConfig = {
                      StandardError = "journal";
                      StandardInput = "tty";
                      StandardOutput = "tty";
                      TTYReset = true;
                      TTYVHangup = true;
                      TTYVTDisallocate = true;
                      Type = "idle";
                    };
                  };
                  system-upgrade = {
                    after = [ "network-online.target" ];
                    path = with pkgs; [
                      nix
                      git
                      networkmanager
                    ];
                    restartIfChanged = false;
                    serviceConfig = {
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
                      Type = "oneshot";
                      User = "root";
                    };
                    unitConfig = {
                      Description = "Update flake inputs and switch NixOS configuration";
                      StartLimitBurst = 5;
                      StartLimitIntervalSec = 300;
                    };
                    wants = [ "network-online.target" ];
                  };
                };
                timers = {
                  system-upgrade = {
                    timerConfig = {
                      OnCalendar = "hourly";
                      Persistent = true;
                      Unit = "system-upgrade.service";
                    };
                    wantedBy = [ "timers.target" ];
                  };
                };
                user = {
                  # paths.qt6ct-colorscheme-fix = {
                  #   description = "Watch qt6ct.conf for DMS color scheme overwrites";
                  #   wantedBy = [ "graphical-session.target" ];
                  #   pathConfig.PathModified = "%h/.config/qt6ct/qt6ct.conf";
                  # };
                  services = {
                    # Fcitx5 input method: clipboard history (Super+V) + unicode/
                    # emoji picker (Super+.). The core i18n.inputMethod module
                    # installs fcitx5-with-addons and generates the config but does
                    # not autostart it, so bind it to the graphical session here.
                    # -D runs in the foreground (systemd tracks it); -r replaces a
                    # stale instance after a compositor respawn.
                    fcitx5 = {
                      after = [ "graphical-session.target" ];
                      description = "Fcitx5 input method (clipboard history + unicode/emoji picker)";
                      partOf = [ "graphical-session.target" ];
                      serviceConfig = {
                        ExecStart = "${config.i18n.inputMethod.package}/bin/fcitx5 -D -r";
                        Restart = "on-failure";
                        RestartSec = 1;
                      };
                      wantedBy = [ "graphical-session.target" ];
                    };

                    # User profile upgrade service
                    nix-profile-upgrade = {
                      after = [ "network-online.target" ];
                      description = "Upgrade user nix profile";
                      path = with pkgs; [
                        nix
                        git
                      ];
                      serviceConfig = {
                        ExecStart = "${pkgs.nix}/bin/nix profile upgrade --all";
                        Restart = "on-failure";
                        RestartSec = "120s";
                        Type = "oneshot";
                      };
                      wants = [ "network-online.target" ];
                    };

                    pipewire = {
                      before = [ "niri.service" ];
                      wantedBy = [ "niri.service" ];
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

                    # Ensure wireplumber waits for UPower to avoid battery query warnings
                    wireplumber = {
                      after = [ "upower.service" ];
                      wants = [ "upower.service" ];
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
                      serviceConfig = {
                        # Main portal must recover from transient startup failures
                        # (D-Bus not ready, display socket unavailable); without this
                        # all portal backends are dead for the session.
                        Restart = "on-failure";
                        RestartMaxDelaySec = 30;
                        RestartSec = 2;
                      };
                    };
                    xdg-desktop-portal-gnome = {
                      after = [ "graphical-session.target" ];
                      partOf = [ "graphical-session.target" ];
                      path = [ config.system.path ];
                      serviceConfig = {
                        Restart = "on-failure";
                        RestartMaxDelaySec = 30;
                        RestartSec = 2;
                      };
                    };
                    xdg-desktop-portal-gtk = {
                      after = [ "graphical-session.target" ];
                      partOf = [ "graphical-session.target" ];
                      path = [ config.system.path ];
                      # Prevent rapid restart loops if display isn't ready
                      serviceConfig = {
                        Restart = "on-failure";
                        RestartMaxDelaySec = 30;
                        RestartSec = 2;
                      };
                    };
                  };
                  timers = {
                    nix-profile-upgrade = {
                      description = "Upgrade user nix profile timer";
                      timerConfig = {
                        OnCalendar = "hourly";
                        Persistent = true;
                        Unit = "nix-profile-upgrade.service";
                      };
                      wantedBy = [ "timers.target" ];
                    };
                  };
                };
              };

              time = {
                timeZone = cfg.timeZone;
              };

              users = {
                defaultUserShell = pkgs.nushell;
                users = {
                  ${cfg.username} = {
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
              };

              xdg = {
                autostart = {
                  enable = mkDefault true;
                };
                icons = {
                  enable = mkDefault true;
                  fallbackCursorThemes = [ "Adwaita" ];
                };
                menus = {
                  enable = mkDefault true;
                };
                mime = {
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
                  enable = mkDefault true;
                };
                portal = {
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
                  # niri-flake's module already adds programs.niri.package here.
                  configPackages = with pkgs; [
                    gnome-keyring
                  ];
                  enable = mkDefault true;
                  extraPortals = with pkgs; [
                    gnome-keyring
                    xdg-desktop-portal-gnome
                    xdg-desktop-portal-gtk
                  ];
                  xdgOpenUsePortal = mkDefault false;
                };
                sounds = {
                  enable = mkDefault true;
                };
                terminal-exec = {
                  enable = mkDefault true;
                  settings = {
                    default = [ "ghostty.desktop" ];
                  };
                };
              };

              zramSwap = {
                enable = mkDefault true;
              };
            };

            imports = [
              inputs.disko.nixosModules.disko
              inputs.niri.nixosModules.niri
              inputs.nix-packagekit.nixosModules.default
            ];

            options = {
              microDesktop = {
                bootMode = mkOption {
                  default = "uefi";
                  description = "Boot mode: uefi (systemd-boot) or legacy (GRUB)";
                  type = types.enum [
                    "uefi"
                    "legacy"
                  ];
                };
                diskDevice = mkOption {
                  default = "/dev/sda";
                  description = "Disk device for installation";
                  type = types.str;
                };
                enableSsh = mkOption {
                  default = false;
                  description = "Enable SSH server";
                  type = types.bool;
                };
                enableVpn = mkOption {
                  default = false;
                  description = "Enable VPN support (installs NetworkManager VPN plugins)";
                  type = types.bool;
                };
                extraPackages = mkOption {
                  default = [ ];
                  description = "Additional packages to install";
                  type = types.listOf types.package;
                };
                hostName = mkOption {
                  default = "nixos";
                  description = "Hostname for the system";
                  type = types.str;
                };
                initialPassword = mkOption {
                  default = "password";
                  description = "Initial password for the user";
                  type = types.str;
                };
                locale = mkOption {
                  default = "en_US.UTF-8";
                  description = "System locale";
                  type = types.str;
                };
                sshPasswordAuth = mkOption {
                  default = true;
                  description = "Allow password authentication for SSH";
                  type = types.bool;
                };
                sshRootLogin = mkOption {
                  default = "yes";
                  description = "Permit root login via SSH";
                  type = types.str;
                };
                stateVersion = mkOption {
                  default = "25.11";
                  description = "NixOS state version";
                  type = types.str;
                };
                timeZone = mkOption {
                  default = "America/New_York";
                  description = "System timezone";
                  type = types.str;
                };
                username = mkOption {
                  default = "user";
                  description = "Primary user name";
                  type = types.str;
                };
              };
            };
          };
      };

      packages = ih.packages;
    };
}
