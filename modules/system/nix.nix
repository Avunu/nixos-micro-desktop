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
        # NixOS defaults this one to 0 while giving nix-optimise 30 minutes, so
        # when both catch up at once — Persistent timers fire on the first boot
        # after a missed run, and on a laptop that is most weeks — the collector
        # and the optimiser start in the same second, alongside everything else
        # that boot is catching up on. A spread keeps them apart.
        randomizedDelaySec = mkDefault "45min";
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
        # max-jobs defaults to "auto" (one slot per hardware thread — 48 on
        # this box), and Nix's scheduler fills every slot it has with zero
        # regard for memory: it only tracks CPU availability. That is fine
        # for ordinary compiles but not for `nix flake check -L` and
        # nixosTests, which the system-features list below allows to run
        # (kvm, nixos-test, big-parallel) — each is a qemu guest holding
        # several GiB of its own, and enough of them scheduled at once has
        # driven this machine past its 125 GiB RAM and 78 GiB swap combined,
        # tripping the swap-based oomd kill in system/memory.nix against
        # whatever cgroup happened to be carrying the most swap (observed:
        # the editor hosting the job, not the job itself). Capping
        # concurrency here bounds the worst case instead of relying on
        # MemoryHigh throttling and the oomd kill to catch it after the
        # fact. Lower than the 48 the hardware could otherwise fill,
        # bounded so that even an unlucky run stacked with several VM tests
        # stays well inside RAM before swap enters the picture at all.
        max-jobs = mkDefault 8;
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
          # into the zswap pool. That is one part of the system compressing
          # into RAM exactly what another part is standing by to compress
          # onto a disk that has room. These two settings have to move
          # together.
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
          # Nice and the idle CPU class keep it off the processor, and the idle
          # I/O class would keep it off the disk — but only under BFQ, which
          # NVMe does not run (see system/hardware.nix). What a person at the
          # machine actually feels is the page cache: the pass reads every file
          # in the store, ~100 GB on a well-used desktop, and on a machine with
          # a few GB of RAM that evicts every editor, browser and library the
          # session had cached, so the desktop faults back in from disk for the
          # next hour. Page cache is charged to the cgroup that read it, so a
          # MemoryHigh here makes the pass recycle its own cache instead of
          # everyone else's; the process itself needs well under 100 MB.
          #
          # The bandwidth cap is blk-throttle, which holds under any scheduler,
          # and bounds the bursts: a measured pass averaged about 25 MB/s, so it
          # costs little time. "/nix/store" rather than a device node, so it
          # follows whatever disk the store is on.
          serviceConfig = {
            MemoryHigh = mkDefault "512M";
            IOReadBandwidthMax = mkDefault "/nix/store 50M";
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
          # Wait for a quiet hour rather than land on a busy one.
          #
          # A rebuild here costs up to its MemoryHigh below (25% of RAM) and was
          # measured holding exactly that for its whole run — 1.9 GB on an 8 GB
          # laptop, with another 1–2.8 GB pushed to swap. Started while the
          # session already needs that memory, it does not just run slowly: it
          # makes the session swap too, for as long as it runs (once, 1h42m).
          # So the condition below skips the run unless at least this share of
          # RAM is available — the same 25% the unit is allowed to use. The
          # timer is hourly, so a skipped run is retried at the next hour; a
          # machine that is never that idle still upgrades at boot.
          environment.UPGRADE_MIN_AVAILABLE_PERCENT = mkDefault "25";
          serviceConfig = {
            Environment = "HOME=/root";
            # Skip gracefully (result=condition, no restart) when on a metered
            # connection, or while the machine is too busy (see above).
            ExecCondition = pkgs.writeShellScript "check-upgrade-conditions" ''
              if ${pkgs.networkmanager}/bin/nmcli -g GENERAL.METERED dev show 2>/dev/null | grep -qi "yes"; then
                echo "Network connection is metered, skipping system upgrade" >&2
                exit 1
              fi

              total=0
              avail=0
              while read -r key value _; do
                case $key in
                  MemTotal:) total=$value ;;
                  MemAvailable:) avail=$value ;;
                esac
              done < /proc/meminfo
              want=''${UPGRADE_MIN_AVAILABLE_PERCENT:-0}
              have=$(( total > 0 ? avail * 100 / total : 100 ))
              if [ "$have" -lt "$want" ]; then
                echo "Only $have% of memory available (want $want%), skipping system upgrade until the machine is less busy" >&2
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
            # IOWeight only means something under BFQ, and NVMe runs "none"
            # (system/hardware.nix). These caps are blk-throttle, which holds
            # under any scheduler: a measured rebuild wrote 2–21 GB, in bursts
            # that otherwise take the whole device. As root, nix builds in this
            # unit's own cgroup rather than the daemon's, so they apply to the
            # builds too. On a slower disk (eMMC) they never bind.
            IOReadBandwidthMax = mkDefault "/nix/store 100M";
            IOWriteBandwidthMax = mkDefault "/nix/store 100M";
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
            # A default, so a host can move it without mkForce.
            OnCalendar = mkDefault "hourly";
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
