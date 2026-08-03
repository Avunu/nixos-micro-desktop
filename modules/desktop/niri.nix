{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.microDesktop;

  # Both non-GNOME shells run on niri; only the bar/panel/greeter differ.
  usesNiri = cfg.desktopShell != "gnome";

  shellUnit = if cfg.desktopShell == "noctalia" then "noctalia.service" else "dms.service";

  shellBinds =
    if cfg.desktopShell == "noctalia" then
      ../../configs/niri/binds-noctalia.kdl
    else
      ../../configs/niri/binds-dms.kdl;

  # /etc/niri/config.kdl is assembled here rather than shipped as one file per
  # shell: the two shells differ only in ~13 IPC binds, and a whole duplicated
  # config drifts. Concatenated rather than relying on niri's `include` merging
  # two `binds` blocks, so there is exactly one authoritative system config.
  niriGlobalConfig = pkgs.writeText "niri-global.kdl" (
    builtins.readFile ../../configs/niri/base.kdl
    + "binds {\n"
    + builtins.readFile ../../configs/niri/binds-common.kdl
    + builtins.readFile shellBinds
    + "}\n"
  );

  # DMS writes these from its settings UI; niri fails to load a config whose
  # `include` target is missing, so they are created empty on activation.
  dmsIncludes = [
    "alttab"
    "binds"
    "colors"
    "cursor"
    "layout"
    "outputs"
    "windowrules"
    "wpblur"
  ];

  niriHomeConfig = pkgs.writeText "niri-home.kdl" (
    ''
      include "/etc/niri/config.kdl"
      include "custom.kdl"
    ''
    + optionalString (cfg.desktopShell == "dms") (
      concatMapStrings (f: "include \"dms/${f}.kdl\"\n") dmsIncludes
    )
  );
in
{
  config = mkIf usesNiri {
    environment = {
      etc = {
        # Deploy niri config system-wide
        "niri/config.kdl" = {
          source = niriGlobalConfig;
        };
      };
      systemPackages = with pkgs; [
        (writeShellScriptBin "restart-shell" ''
          systemctl --user restart ${shellUnit}
        '')
        brightnessctl
        cava
        cliphist
        gammastep
        grim
        matugen
        playerctl
        satty
        slurp
        wlr-randr
      ];
      variables = {
        XDG_CURRENT_DESKTOP = "niri";
        XDG_SESSION_DESKTOP = "niri";
      };
    };

    programs = {
      # Package defaults to nixpkgs' niri, served from cache.nixos.org.
      niri = {
        enable = mkDefault true;
        useNautilus = mkDefault true;
      };
    };

    security = {
      pam = {
        services = {
          greetd = {
            enableGnomeKeyring = mkDefault true;
          };
        };
      };
    };

    services = {
      displayManager = {
        defaultSession = "niri";
        # niri's own module already adds programs.niri.package to
        # sessionPackages, and systemd.packages registers niri.service.
      };
      greetd = {
        enable = mkDefault true;
        settings = {
          default_session = {
            user = mkDefault "greeter";
          };
        };
      };
      iio-niri = {
        enable = mkDefault true;
      };
    };

    system = {
      activationScripts = {
        # Install user niri config to ~/.config/niri/config.kdl
        niriUserConfig = ''
          USER_HOME="/home/${cfg.username}"
          NIRI_CONFIG_DIR="$USER_HOME/.config/niri"

          if [ -d "$USER_HOME" ]; then
          mkdir -p "$NIRI_CONFIG_DIR"

          # Always update config.kdl from the nix store
          cp ${niriHomeConfig} "$NIRI_CONFIG_DIR/config.kdl"

          # Create custom.kdl only if it doesn't exist (user's personal overrides)
          [ -f "$NIRI_CONFIG_DIR/custom.kdl" ] || touch "$NIRI_CONFIG_DIR/custom.kdl"

          ${optionalString (cfg.desktopShell == "dms") ''
            mkdir -p "$NIRI_CONFIG_DIR/dms"
            for f in ${concatStringsSep " " dmsIncludes}; do
              [ -f "$NIRI_CONFIG_DIR/dms/$f.kdl" ] || touch "$NIRI_CONFIG_DIR/dms/$f.kdl"
            done
          ''}

          chown -R ${cfg.username}:users "$USER_HOME/.config"
          fi
        '';
      };
    };

    systemd = {
      services = {
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
      };

      user = {
        services = {
          # Make the compositor the last thing on the machine to be
          # killed for memory, not one of the first.
          #
          # asDropin, because niri.service itself comes from
          # programs.niri.package via the niri module's systemd.packages —
          # a full unit definition here would replace it and lose its
          # ExecStart.
          #
          # This value only takes effect in combination with the
          # OOMScoreAdjust on user@.service (see system/memory.nix).
          # Lowering oom_score_adj requires CAP_SYS_RESOURCE, which the
          # per-user systemd manager does not have, so it cannot set any of
          # its units below its own value — it clamps silently rather than
          # failing, which makes a too-low value here look applied while
          # doing nothing at all. Both numbers must therefore move together.
          #
          # -900 rather than -1000: a wedged compositor holding all of RAM
          # should still be reachable as an absolute last resort. niri now
          # sorts below applications (+300), below the container runtimes
          # (-500), and only above sshd (-1000), which is deliberately the
          # final way back into the machine.
          #
          # ManagedOOMPreference=omit additionally removes it from
          # systemd-oomd's candidate set — oomd chooses by cgroup pressure
          # and ignores the kernel score entirely, so it needs telling
          # separately. Unlike OOMScoreAdjust this one is a cgroup xattr
          # and does apply unprivileged.
          niri = {
            overrideStrategy = "asDropin";
            serviceConfig = {
              ManagedOOMPreference = "omit";
              OOMScoreAdjust = -900;
            };
          };

          pipewire = {
            before = [ "niri.service" ];
            wantedBy = [ "niri.service" ];
          };
        };
      };
    };
  };
}
