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

  # Noctalia writes its generated theme (focus-ring/border colours) here and
  # expects the user config to include it. Like the DMS files above, niri
  # refuses to load a config whose `include` target is missing.
  shellIncludes = optional (cfg.desktopShell == "noctalia") "noctalia";

  # Include order is precedence order: later files win. NiriMod's file comes
  # before the shell-generated ones so a shell's theme/outputs are never
  # shadowed by a stale visual-editor setting.
  niriHomeConfig = pkgs.writeText "niri-home.kdl" (
    ''
      include "/etc/niri/config.kdl"
      include "nirimod.kdl"
    ''
    + concatMapStrings (f: "include \"${f}.kdl\"\n") shellIncludes
    + optionalString (cfg.desktopShell == "dms") (
      concatMapStrings (f: "include \"dms/${f}.kdl\"\n") dmsIncludes
    )
  );

  # NiriMod is a visual editor for niri. It is pointed at nirimod.kdl rather
  # than config.kdl: config.kdl is rewritten from the nix store on every
  # activation, so anything NiriMod saved there would be lost, whereas
  # nirimod.kdl is user state that this module only ever creates, never
  # overwrites.
  #
  # Baseline for ~/.config/nirimod/settings.json. NiriMod rewrites this file
  # itself (dismissed prompts, preferences), so the activation script merges
  # rather than copies — see below.
  nirimodSettings = pkgs.writeText "nirimod-settings.json" (
    builtins.toJSON {
      auto_backup = true;
      auto_update = false; # nix owns the package; the in-app updater cannot
      backup_limit = 10;
      backup_path = "";
      config_path = "/home/${cfg.username}/.config/niri/nirimod.kdl";
      kofi_v3_dont_show = true;
      kofi_v4_dont_show = true;
    }
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
        nirimod
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
        # Provision the user's niri and NiriMod config.
        #
        # config.kdl is Nix-owned and overwritten every time. Everything else
        # is created only when missing, so it is safe to edit by hand or
        # through NiriMod.
        niriUserConfig = ''
          USER_HOME="/home/${cfg.username}"
          NIRI_CONFIG_DIR="$USER_HOME/.config/niri"
          NIRIMOD_CONFIG_DIR="$USER_HOME/.config/nirimod"

          if [ -d "$USER_HOME" ]; then
            mkdir -p "$NIRI_CONFIG_DIR" "$NIRIMOD_CONFIG_DIR"

            cp ${niriHomeConfig} "$NIRI_CONFIG_DIR/config.kdl"

            # nirimod.kdl replaces the old hand-edited custom.kdl as the
            # user's own layer. Carry existing content over once.
            if [ ! -e "$NIRI_CONFIG_DIR/nirimod.kdl" ] && [ -f "$NIRI_CONFIG_DIR/custom.kdl" ]; then
              mv "$NIRI_CONFIG_DIR/custom.kdl" "$NIRI_CONFIG_DIR/nirimod.kdl"
            fi
            for f in nirimod ${concatStringsSep " " shellIncludes}; do
              [ -f "$NIRI_CONFIG_DIR/$f.kdl" ] || touch "$NIRI_CONFIG_DIR/$f.kdl"
            done

            ${optionalString (cfg.desktopShell == "dms") ''
              mkdir -p "$NIRI_CONFIG_DIR/dms"
              for f in ${concatStringsSep " " dmsIncludes}; do
                [ -f "$NIRI_CONFIG_DIR/dms/$f.kdl" ] || touch "$NIRI_CONFIG_DIR/dms/$f.kdl"
              done
            ''}

            # Baseline <- existing <- Nix-owned keys. Missing keys are filled
            # in and the user's own preferences survive, but config_path is
            # always forced back to nirimod.kdl: left at NiriMod's default it
            # would edit config.kdl, which is overwritten above.
            SETTINGS="$NIRIMOD_CONFIG_DIR/settings.json"
            SETTINGS_NEW="$SETTINGS.new"
            if [ -f "$SETTINGS" ] && ${pkgs.jq}/bin/jq -e . "$SETTINGS" >/dev/null 2>&1; then
              ${pkgs.jq}/bin/jq -S -s '.[0] * .[1] * {config_path: .[0].config_path}' \
                ${nirimodSettings} "$SETTINGS" > "$SETTINGS_NEW"
            else
              ${pkgs.jq}/bin/jq -S . ${nirimodSettings} > "$SETTINGS_NEW"
            fi
            if cmp -s "$SETTINGS_NEW" "$SETTINGS"; then
              rm -f "$SETTINGS_NEW"
            else
              mv "$SETTINGS_NEW" "$SETTINGS"
            fi

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
          #
          # The three cgroup weights are the other half of the same idea, on
          # the axes an OOM score does not cover. system/nix.nix holds
          # nix-daemon and the scheduled rebuild to a reduced share of CPU and
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
