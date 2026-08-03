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
in
{
  config = {
    environment = {
      etc = {
        "nix/nixpkgs-config.nix" = {
          text = lib.mkDefault ''
            {
              allowUnfree = true;
            }
          '';
        };
      };
      systemPackages = with pkgs; [
        (writeShellScriptBin "profile-upgrade" ''
          nix profile upgrade --all --impure
        '')
        systemUpgradeScript
      ];
    };

    nix = {
      gc = {
        automatic = mkDefault true;
        dates = mkDefault "weekly";
        options = mkDefault "--delete-older-than 7d";
      };
      settings = {
        auto-optimise-store = true;
        # Free space on demand, not just on the weekly gc timer.
        #
        # system-upgrade below rebuilds hourly from nixpkgs-unstable, so
        # the store can gain many gigabytes between two runs of a weekly
        # collector. When the root filesystem actually reached 100% the
        # failure was not graceful: nix started taking SIGBUS on its mmap
        # of the store database, systemd-coredump could not write the
        # dumps ("No space left on device"), and the machine hung hard
        # with no shutdown sequence in the journal. min-free/max-free let
        # the daemon collect garbage mid-build, which is the only thing
        # that runs between weekly GCs.
        max-free = 80 * 1024 * 1024 * 1024; # ...then free up to 80 GiB
        min-free = 20 * 1024 * 1024 * 1024; # collect below 20 GiB free
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
    };

    services = {
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
    };

    system = {
      autoUpgrade = {
        enable = mkDefault false;
      };
      stateVersion = cfg.stateVersion;
    };

    systemd = {
      services = {
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
        services = {
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
  };
}
