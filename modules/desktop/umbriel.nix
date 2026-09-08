{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.microDesktop;

  usesUmbriel = cfg.desktopShell == "noctalia";

  tomlFormat = pkgs.formats.toml { };

  # Umbriel resolves `[include]`/`[include.optional]` relative to the
  # declaring file, and — unlike niri's include semantics — the file that
  # declares the include always wins over anything it includes. So the
  # Nix-managed settings below live in their own file that gets included,
  # while the small, always-preserved config.toml is the includer: any
  # setting a user adds there directly beats the generated file, mirroring
  # what niri's custom.kdl does (see niri.nix) even though the mechanics run
  # in the opposite direction.
  umbrielSettings = {
    layout = {
      # niri had only one layout; keep this explicit since the scrolling
      # strip is the one behavior this migration must not regress.
      mode = "scrolling";
      gap = 16;
      struts = {
        left = 0;
        right = 0;
        top = 0;
        bottom = 0;
      };
      scrolling = {
        center_focused = false;
      };
    };

    # Approximates niri's `focus-ring { width 4; } border { off; }`: umbriel
    # always draws a border at border_width, so making the unfocused color
    # fully transparent leaves a ring visible only on the focused window.
    appearance = {
      border_width = 4;
    };

    colors = {
      border = {
        unfocused = "#00000000";
      };
    };

    input = {
      keyboard = {
        layout = "";
        variant = "";
        options = "";
        repeat_rate = 25;
        repeat_delay = 600;
        track_layout = "global";
      };
      touchpad = {
        tap = true;
        natural_scroll = true;
      };
      cursor = {
        theme = "";
        size = 24;
      };
    };

    # Every chord niri bound is declared here explicitly rather than left to
    # umbriel's own built-in keymap: umbriel's defaults are pre-1.0 and
    # explicitly "not a stability promise" upstream, so relying on them
    # matching niri by coincidence would be fragile.
    keybinds = {
      # Apps and session
      "Mod+Ctrl+R" = "spawn:restart-shell";
      "Mod+T" = "spawn:ghostty";
      "Print" = "spawn:noctalia msg screenshot-region";

      # Focus navigation
      "Mod+H" = "window-focus-left";
      "Mod+Left" = "window-focus-left";
      "Mod+L" = "window-focus-right";
      "Mod+Right" = "window-focus-right";
      "Mod+J" = "window-focus-down";
      "Mod+Down" = "window-focus-down";
      "Mod+K" = "window-focus-up";
      "Mod+Up" = "window-focus-up";
      "Mod+Home" = "column-focus-first";
      "Mod+End" = "column-focus-last";
      "Mod+I" = "workspace-previous";
      "Mod+Page_Up" = "workspace-previous";
      "Mod+U" = "workspace-next";
      "Mod+Page_Down" = "workspace-next";

      # Move columns/windows
      "Mod+Ctrl+H" = "column-move-left";
      "Mod+Ctrl+Left" = "column-move-left";
      "Mod+Ctrl+L" = "column-move-right";
      "Mod+Ctrl+Right" = "column-move-right";
      "Mod+Ctrl+J" = "window-move-down";
      "Mod+Ctrl+Down" = "window-move-down";
      "Mod+Ctrl+K" = "window-move-up";
      "Mod+Ctrl+Up" = "window-move-up";
      "Mod+Ctrl+Home" = "column-move-to-first";
      "Mod+Ctrl+End" = "column-move-to-last";
      "Mod+Ctrl+I" = "column-move-to-workspace-previous";
      "Mod+Ctrl+Page_Up" = "column-move-to-workspace-previous";
      "Mod+Ctrl+U" = "column-move-to-workspace-next";
      "Mod+Ctrl+Page_Down" = "column-move-to-workspace-next";

      # Column/window sizing
      "Mod+Equal" = "window-modify-width:0.1";
      "Mod+Minus" = "window-modify-width:-0.1";
      "Mod+Shift+Equal" = "window-modify-height:0.1";
      "Mod+Shift+Minus" = "window-modify-height:-0.1";
      "Mod+R" = "window-cycle-width";

      # Window state. Mod+F/Mod+Shift+F are deliberately swapped from
      # umbriel's own suggested convention (fullscreen/maximize) to match
      # niri's (maximize/fullscreen).
      "Mod+Q" = "window-close";
      "Mod+F" = "window-toggle-maximize";
      "Mod+Shift+F" = "window-toggle-fullscreen";
      "Mod+C" = "column-center";
      # Closest equivalent to niri's always-expel; umbriel merges consume
      # and expel into one bidirectional action.
      "Mod+Shift+Period" = "window-consume-or-expel-right";

      # Monitor (output) focus/move
      "Mod+Shift+H" = "output-focus-left";
      "Mod+Shift+Left" = "output-focus-left";
      "Mod+Shift+L" = "output-focus-right";
      "Mod+Shift+Right" = "output-focus-right";
      "Mod+Shift+J" = "output-focus-down";
      "Mod+Shift+Down" = "output-focus-down";
      "Mod+Shift+K" = "output-focus-up";
      "Mod+Shift+Up" = "output-focus-up";
      "Mod+Shift+Ctrl+H" = "column-move-to-output-left";
      "Mod+Shift+Ctrl+Left" = "column-move-to-output-left";
      "Mod+Shift+Ctrl+L" = "column-move-to-output-right";
      "Mod+Shift+Ctrl+Right" = "column-move-to-output-right";
      "Mod+Shift+Ctrl+J" = "column-move-to-output-down";
      "Mod+Shift+Ctrl+Down" = "column-move-to-output-down";
      "Mod+Shift+Ctrl+K" = "column-move-to-output-up";
      "Mod+Shift+Ctrl+Up" = "column-move-to-output-up";

      # Workspace move
      "Mod+Shift+I" = "workspace-move-up";
      "Mod+Shift+Page_Up" = "workspace-move-up";
      "Mod+Shift+U" = "workspace-move-down";
      "Mod+Shift+Page_Down" = "workspace-move-down";

      # System
      "Mod+Shift+E" = "session-quit";
      "Mod+Shift+P" = "dpms-off";
      "Mod+Shift+Slash" = "cheatsheet-open";

      # Keyboard backlight
      "Mod+Alt+XF86MonBrightnessDown" = {
        action = "spawn:brightnessctl --device=*::kbd_backlight set 5%-";
        allow_when_locked = true;
      };
      "Mod+Alt+XF86MonBrightnessUp" = {
        action = "spawn:brightnessctl --device=*::kbd_backlight set +5%";
        allow_when_locked = true;
      };

      # Noctalia IPC. Mod+Comma deliberately overrides umbriel's built-in
      # window-consume-left, matching niri which left Comma free for this.
      "Mod+Alt+L" = "spawn:noctalia msg session lock";
      "Mod+Alt+N" = {
        action = "spawn:noctalia msg nightlight-toggle";
        allow_when_locked = true;
      };
      "Mod+Comma" = "spawn:noctalia msg settings-toggle";
      "Mod+N" = "spawn:noctalia msg panel-toggle control-center";
      "Mod+Space" = "spawn:noctalia msg panel-toggle launcher";
      "Mod+X" = "spawn:noctalia msg panel-toggle session";

      # Media keys
      "XF86AudioLowerVolume" = {
        action = "spawn:noctalia msg volume-down 3";
        allow_when_locked = true;
      };
      "XF86AudioMicMute" = {
        action = "spawn:noctalia msg mic-mute";
        allow_when_locked = true;
      };
      "XF86AudioMute" = {
        action = "spawn:noctalia msg volume-mute";
        allow_when_locked = true;
      };
      "XF86AudioRaiseVolume" = {
        action = "spawn:noctalia msg volume-up 3";
        allow_when_locked = true;
      };
      "XF86MonBrightnessDown" = {
        action = "spawn:noctalia msg brightness-down 5";
        allow_when_locked = true;
      };
      "XF86MonBrightnessUp" = {
        action = "spawn:noctalia msg brightness-up 5";
        allow_when_locked = true;
      };
    };
  };

  umbrielGeneratedToml = tomlFormat.generate "umbriel-generated.toml" umbrielSettings;
in
{
  config = mkIf usesUmbriel {
    environment = {
      variables = {
        XDG_CURRENT_DESKTOP = "umbriel";
        XDG_SESSION_DESKTOP = "umbriel";
      };
    };

    programs = {
      # Package/portalPackage default to nixpkgs' umbriel and
      # xdg-desktop-portal-umbriel, same "defaults to nixpkgs'" pattern as
      # programs.niri.
      umbriel = {
        enable = mkDefault true;
      };
    };

    services = {
      displayManager = {
        defaultSession = "umbriel";
        # umbriel's own module already adds programs.umbriel.package to
        # sessionPackages, and systemd.packages registers umbriel.service.
      };
    };

    system = {
      activationScripts = {
        # Install the umbriel config to ~/.config/umbriel/.
        umbrielUserConfig = ''
          USER_HOME="/home/${cfg.username}"
          UMBRIEL_CONFIG_DIR="$USER_HOME/.config/umbriel"

          if [ -d "$USER_HOME" ]; then
          mkdir -p "$UMBRIEL_CONFIG_DIR"

          # Always update the Nix-managed settings from the store.
          cp ${umbrielGeneratedToml} "$UMBRIEL_CONFIG_DIR/umbriel-generated.toml"

          # Create config.toml only if it doesn't exist: it includes the
          # generated settings and is otherwise the user's personal-override
          # file (see the comment on umbrielSettings above for why the
          # includer/included roles run this way round).
          if [ ! -f "$UMBRIEL_CONFIG_DIR/config.toml" ]; then
            printf '%s\n' '[include]' 'files = ["umbriel-generated.toml"]' > "$UMBRIEL_CONFIG_DIR/config.toml"
          fi

          chown -R ${cfg.username}:users "$USER_HOME/.config"
          fi
        '';
      };
    };

    systemd = {
      user = {
        services = {
          # Make the compositor the last thing on the machine to be killed
          # for memory, not one of the first — same reasoning as niri's own
          # drop-in (see niri.nix), just re-pointed at umbriel.service.
          #
          # asDropin, because umbriel.service itself comes from
          # programs.umbriel.package via the umbriel module's
          # systemd.packages — a full unit definition here would replace it
          # and lose its ExecStart.
          umbriel = {
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
            before = [ "umbriel.service" ];
            wantedBy = [ "umbriel.service" ];
          };
        };
      };
    };
  };
}
