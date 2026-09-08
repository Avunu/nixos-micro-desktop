{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.microDesktop;

  # niri is dms's compositor only; noctalia runs on umbriel (see umbriel.nix).
  usesNiri = cfg.desktopShell == "dms";

  # /etc/niri/config.kdl is assembled here rather than shipped as a single
  # static file, so a system config change doesn't require touching the
  # binds file directly.
  niriGlobalConfig = pkgs.writeText "niri-global.kdl" (
    builtins.readFile ../../configs/niri/base.kdl
    + "binds {\n"
    + builtins.readFile ../../configs/niri/binds-common.kdl
    + builtins.readFile ../../configs/niri/binds-dms.kdl
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
    + concatMapStrings (f: "include \"dms/${f}.kdl\"\n") dmsIncludes
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

    services = {
      displayManager = {
        defaultSession = "niri";
        # niri's own module already adds programs.niri.package to
        # sessionPackages, and systemd.packages registers niri.service.
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

          mkdir -p "$NIRI_CONFIG_DIR/dms"
          for f in ${concatStringsSep " " dmsIncludes}; do
            [ -f "$NIRI_CONFIG_DIR/dms/$f.kdl" ] || touch "$NIRI_CONFIG_DIR/dms/$f.kdl"
          done

          chown -R ${cfg.username}:users "$USER_HOME/.config"
          fi
        '';
      };
    };

    systemd = {
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
          #
          # The three cgroup weights are the other half of the same idea, on
          # the axes an OOM score does not cover. system/nix.nix holds
          # nix-daemon and the hourly rebuild to a reduced share of CPU and
          # I/O; these raise the compositor's share above the default so that
          # a rebuild competing for the disk cannot stall a repaint.
          #
          # MemoryLow, not MemoryMin: MemoryLow makes the compositor's pages
          # the last ones reclaimed, while MemoryMin makes them unreclaimable
          # and turns a memory squeeze into a kill somewhere else on the
          # system. The protection wanted here is the soft one.
          niri = {
            overrideStrategy = "asDropin";
            serviceConfig = {
              CPUWeight = 200;
              IOWeight = 200;
              ManagedOOMPreference = "omit";
              MemoryLow = "512M";
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
