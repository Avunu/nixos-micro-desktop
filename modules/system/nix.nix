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
      gitMinimal
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
      # Store deduplication, moved off the interactive path.
      #
      # What it saves is not in question: a Nix store carries a great many
      # byte-identical files across generations and packages, and no compression
      # ratio touches a duplicate, so this and the root-filesystem zstd in
      # system/storage.nix save different things and neither substitutes for
      # the other. The question is only when it runs.
      #
      # auto-optimise-store (set below until now) ran it inline: every
      # substituted path hashed and hard-linked before nix would call the build
      # done, while someone was waiting. system-upgrade below rebuilds hourly
      # from nixpkgs-unstable, so that was happening every hour, in the
      # foreground, on a desktop someone is using. The timer does the same work
      # when nobody is typing.
      #
      # The honest counter-argument: inline optimisation hashes files it has
      # just written, so they are still in page cache, whereas nix-store
      # --optimise walks the whole store cold. This trades more total I/O for
      # I/O that happens at a better time. It also leaves the store
      # un-deduplicated between passes — which is what the min-free floor below
      # is there to survive, and why the cadence is weekly rather than monthly.
      optimise = {
        automatic = mkDefault true;
        dates = mkDefault [ "weekly" ];
      };
      settings = {
        auto-optimise-store = mkDefault false;
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
        # ── Resource guards ───────────────────────────────────────
        #
        # memory.nix already keeps an out-of-memory event from selecting the
        # compositor. This is the same idea on the two axes it does not cover:
        # CPU and I/O. The offender it is aimed at is this module's own hourly
        # rebuild — a `nixos-rebuild switch` against nixpkgs-unstable can
        # substitute or build several gigabytes without warning, and the
        # resulting page-cache eviction is felt as a session that stops
        # repainting long before anything is close to being OOM-killed.
        #
        # MemoryHigh rather than MemoryMax throughout: this should throttle
        # reclaim, not fail the build.
        nix-daemon = {
          # Build scratch goes to /var/tmp, not /tmp.
          #
          # boot.nix puts /tmp on tmpfs, and tmpfs pages are charged to whoever
          # allocated them — so an unpacked source tree under /tmp counts
          # against the MemoryHigh below, and reclaiming it pushes that tree
          # into zram. That is one part of the system compressing into RAM
          # exactly what another part is standing by to compress onto a disk
          # that has room. These two settings have to move together.
          environment.TMPDIR = mkDefault "/var/tmp";
          serviceConfig = {
            CPUWeight = mkDefault 50;
            IOWeight = mkDefault 50;
            # Covers child builds too, not just the daemon, because
            # settings.use-cgroups above puts each build in its own child
            # cgroup of this unit.
            MemoryHigh = mkDefault "40%";
            # Scoped to this unit deliberately. memory.nix runs oomd across the
            # user slices so a runaway app dies before the session does; adding
            # a pressure trigger here means a build storm is answered by
            # killing the build rather than by killing anything of the user's.
            ManagedOOMMemoryPressure = mkDefault "kill";
            ManagedOOMMemoryPressureLimit = mkDefault "80%";
          };
        };

        # NixOS schedules nix-optimise politely already (Nice = 19, idle CPU
        # and I/O classes) but also gates it on ConditionACPower, at normal
        # priority — so mkDefault loses silently here and the weekly pass
        # simply never runs on a laptop that is usually unplugged. mkForce is
        # load-bearing.
        #
        # The value is the empty string, not false. systemd reads
        # ConditionACPower=false as "hold only if at least one AC connector is
        # known and all of them are disconnected" — that is *battery only*,
        # which would invert the intent rather than remove it. An empty
        # assignment resets the condition list, which is what "run regardless
        # of power state" actually looks like.
        nix-optimise = {
          unitConfig = {
            ConditionACPower = mkForce "";
          };
        };

        system-upgrade = {
          after = [ "network-online.target" ];
          path = with pkgs; [
            nix
            gitMinimal
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
            # Tighter than nix-daemon's: this runs unprompted, on a timer, while
            # someone is using the machine. A full flake evaluation transiently
            # costs hundreds of megabytes on its own, before any build starts.
            CPUWeight = mkDefault 20;
            IOWeight = mkDefault 20;
            MemoryHigh = mkDefault "25%";
            Nice = mkDefault 19;
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
              gitMinimal
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
