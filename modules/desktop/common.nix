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
  config = {
    environment = {
      etc = {
        # Fix Electron CHROME_DESKTOP on NixOS: preload script that derives
        # the correct .desktop name from process.argv at JS init time.
        "environment.d/60-electron-chrome-desktop.conf" = {
          text = ''
            NODE_OPTIONS="--require=${../../scripts/electron-chrome-desktop-fix.js}"
          '';
        };
        # deploy default GTK config
        "gtk-3.0/settings.ini" = {
          source = ../../configs/gtk-3.0-settings.ini;
        };
        "gtk-4.0/settings.ini" = {
          source = ../../configs/gtk-4.0-settings.ini;
        };
        # "xdg/menus/applications.menu".source =
        #   "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
        # "xdg/qt6ct/qt6ct.conf".source = ../../configs/qt6ct.conf;
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
      systemPackages =
        with pkgs;
        lib.flatten [
          [
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
            darkly
            decibels
            dsearch
            ffmpeg-headless
            ffmpegthumbnailer
            gcr_4
            gdk-pixbuf
            ghostty
            glib
            gnome-menus
            gnome-packagekit
            gnome-software
            gnome-themes-extra
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
            mission-center
            morewaita-icon-theme
            nautilus
            packagekit
            papers
            ripgrep
            shared-mime-info
            showtime
            uutils-coreutils-noprefix
            wl-clipboard
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
        # PROTOC and SDL_SOUNDFONTS were removed here. Both were string-valued
        # environment variables whose only effect was to pull their package
        # into the system closure: protobuf (73 MB) so that something could
        # compile a .proto at runtime, and soundfont-fluid (141 MB) so that SDL
        # could synthesize MIDI. Neither has a consumer on this desktop. An
        # environment variable interpolating a store path is a closure
        # reference like any other.
        QML_DISABLE_DISK_CACHE = "1";
        QSG_RHI_BACKEND = "vulkan";
        QT_QPA_PLATFORM = "wayland";
        QT_QPA_PLATFORMTHEME = "gtk3";
        QT_SCALE_FACTOR_ROUNDING_POLICY = "RoundPreferFloor";
        QT_STYLE_OVERRIDE = "Fusion";
        SAL_ENABLESKIA = "1";
        SAL_FORCESKIA = "1";
        SAL_SKIA = "vulkan";
        SDL_VIDEODRIVER = "wayland";
        # SQLite performance: use /tmp (tmpfs, see boot.tmp.useTmpfs) for temp
        # files instead of the compressed root filesystem
        SQLITE_TMPDIR = "/tmp";
        TERMINAL = getExe pkgs.ghostty;
        XDG_SESSION_TYPE = "wayland";
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

        # Greeter/shell fonts (DankMaterialShell and Noctalia both want these)
        inter
        material-symbols
      ];
    };

    gtk = {
      iconCache = {
        enable = mkDefault true;
      };
    };

    programs = {
      # Off unless microDesktop.enableAppImage is set: the FHS sandbox this
      # builds carries the full 222 MB glibc locale archive, taken from
      # pkgs.glibcLocales rather than from i18n.supportedLocales, which undoes
      # the locale trim in system/users.nix on its own. See the option for the
      # two alternatives that were measured and rejected.
      appimage = {
        enable = mkDefault cfg.enableAppImage;
      };
      dconf = {
        enable = mkDefault true;
      };
      gnupg = {
        agent = {
          enable = mkDefault true;
          enableSSHSupport = mkDefault false; # Using gcr-ssh-agent for SSH
          pinentryPackage = mkDefault pkgs.pinentry-gnome3;
        };
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

    services = {
      accounts-daemon = {
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
        # Content indexing, off unless microDesktop.enableFileIndexing is set.
        #
        # localsearch walks $HOME on a schedule and re-reads every file it can
        # parse to keep a full-text index current; tinysparql is the store it
        # writes into. What that buys is content search inside Nautilus. What
        # it costs is a recurring crawl over the user's data on a machine whose
        # root filesystem is transparently compressed, so every re-read is also
        # a decompression.
        #
        # File-name search still works with this off, and `dsearch` (in
        # systemPackages above) covers fuzzy filesystem search independently —
        # it has no tinysparql dependency.
        localsearch = {
          enable = mkDefault cfg.enableFileIndexing;
        };
        sushi = {
          enable = mkDefault true;
        };
        tinysparql = {
          enable = mkDefault cfg.enableFileIndexing;
        };
      };
      gvfs = {
        enable = mkDefault true;
        package = mkDefault pkgs.gnome.gvfs;
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
      udev = {
        packages = with pkgs; [ gnome-settings-daemon ];
      };
    };

    systemd = {
      user = {
        services = {
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
  };
}
