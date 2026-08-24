{
  lib,
  pkgs,
  ...
}:
with lib;
let
  # Attributes runaway `shmem` growth back to the process holding it.
  #
  # Sessions were being destroyed by global OOM kills in which ~100% of
  # RAM was accounted to `shmem` while no process had a large RSS. That
  # shape means leaked memfd / Wayland-shm / SysV segments: the pages are
  # charged to the shared-memory pool, not to any task's RSS, so `top`,
  # `ps` and `systemd-cgtop` all show a machine with plenty of free
  # memory right up until the OOM killer fires. Nothing in userspace maps
  # shmem back to its allocator, so sample it here and, only once it
  # crosses a threshold, dump the fd holders. Costs a few ms per run and
  # stays silent unless something is actually wrong.
  shmemWatchdogScript = pkgs.writeShellApplication {
    name = "shmem-watchdog";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      gnugrep
    ];
    text = ''
      threshold=''${SHMEM_WARN_PERCENT:-35}

      total=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
      shmem=$(awk '/^Shmem:/{print $2}' /proc/meminfo)
      pct=$(( shmem * 100 / total ))

      if [ "$pct" -lt "$threshold" ]; then
        exit 0
      fi

      echo "shmem is $pct% of RAM ($(( shmem / 1024 )) MiB) — over ''${threshold}% threshold."
      echo "Shared-memory pages are not counted in RSS; listing fd holders and RssShmem instead."

      # Column 1 is the count of memfd/shm descriptors the process holds
      # open, column 2 its RssShmem (the part it currently has mapped).
      # A large fd count with a small RssShmem is the leak signature:
      # buffers allocated and abandoned without ever being unmapped.
      for p in /proc/[0-9]*; do
        pid=''${p#/proc/}

        # readlink per fd rather than parsing `ls -l`: fd targets are
        # attacker-influenced strings (a file named "memfd:..." would
        # forge a match) and disappear mid-scan as processes run.
        fds=0
        for fd in "$p"/fd/*; do
          target=$(readlink "$fd" 2>/dev/null) || continue
          case "$target" in
            /memfd:* | /dev/shm/* | /SYSV*) fds=$(( fds + 1 )) ;;
          esac
        done

        rss=$(awk '/^RssShmem:/{print $2}' "$p/status" 2>/dev/null || true)
        if [ "$fds" -gt 0 ] || [ "''${rss:-0}" -gt 0 ]; then
          printf '%6s fds  %9s kB RssShmem  pid=%-8s %s\n' \
            "$fds" "''${rss:-0}" "$pid" \
            "$(cat "$p/comm" 2>/dev/null || echo '?')"
        fi
      done | sort -rn | head -25

      echo "tmpfs usage (a full tmpfs is shmem too, and is the easy case):"
      df -h -t tmpfs || true
    '';
  };
in
{
  config = {
    boot = {
      kernel = {
        sysctl = {
          # Stop the kernel compacting memory speculatively in the background.
          # Compaction exists to produce contiguous high-order pages, and with
          # transparent_hugepage=madvise on the kernel command line almost
          # nothing here asks for them — so proactive compaction is CPU and
          # page migration spent on a supply nobody is drawing from. On-demand
          # compaction still happens when an allocation actually needs it.
          "vm.compaction_proactiveness" = mkDefault 0;
          "vm.dirty_background_ratio" = mkDefault 5; # Start background writeback early
          "vm.dirty_ratio" = mkDefault 10; # default; elevated values increase unreclaimable memory pressure
          # Single-page swap reads, which is what zram wants: a zram fault is
          # a decompression, so reading seven neighbouring pages that nobody
          # asked for is seven decompressions wasted. zram is the swap of
          # consequence here — it sits at priority 100, above the disk swap
          # partition microDesktop.swapSizeGiB creates (see system/storage.nix)
          # — so it is the tier to tune for. The cost is that the disk
          # partition, once anything reaches it, reads a page at a time and is
          # correspondingly slow. That tier is a last-resort safety net and a
          # hibernation target, not a working set, so the trade is the right
          # way round.
          "vm.page-cluster" = mkDefault 0;
          "vm.swappiness" = mkDefault 100; # zram benefits from eager compression; 100 avoids OOM before zram fills
          "vm.vfs_cache_pressure" = mkDefault 50; # Keep inodes/dentries cached longer for SQLite
        };
      };
    };

    systemd = {
      # ── Out-of-memory policy ──────────────────────────────────────
      #
      # Losing the compositor means losing every open window, so an OOM
      # event must never be allowed to select it. By default it is
      # exactly what gets selected: systemd gives user@.service an
      # OOMScoreAdjust of 100 and its children inherit 200, while
      # dockerd/containerd set themselves to -500 and sshd to -1000. The
      # kernel therefore ranks the compositor as *more* disposable than
      # the container runtime, and when memory runs out it kills the
      # compositor, its unit has OOMPolicy=stop, the session ends and the
      # display manager drops back to the greeter. That is the "it logged
      # itself out" symptom, and it is a scoring bug rather than a memory
      # bug: the session dies even when the process that exhausted memory
      # is an unrelated background app.
      #
      # Two layers, covering different failure shapes:
      #
      #   1. systemd-oomd (here) watches per-cgroup PSI pressure and swap
      #      usage and kills the worst-offending *application* early,
      #      while the machine is still responsive. NixOS enables the
      #      daemon by default but ships no ManagedOOM* policy at all, so
      #      out of the box it monitors nothing and never acts — which is
      #      why the kernel OOM killer got there first and spent four
      #      minutes killing eighteen processes before reaching niri.
      #   2. OOMScoreAdjust/ManagedOOMPreference on the compositor unit
      #      (see the per-shell modules), for when the kernel OOM killer
      #      runs anyway — oomd cannot help against an allocation spike
      #      faster than its polling interval.
      oomd = {
        enable = mkDefault true;
        # ManagedOOMMemoryPressure=kill on -.slice.
        enableRootSlice = mkDefault true;
        # ...and on user.slice plus every slice inside the user manager,
        # so a runaway app is killed in preference to the session.
        enableUserSlices = mkDefault true;
      };

      services = {
        shmem-watchdog = {
          description = "Attribute runaway shared-memory growth to a process";
          serviceConfig = {
            ExecStart = lib.getExe shmemWatchdogScript;
            Type = "oneshot";
            User = "root";
          };
        };

        # Lower the floor under the whole user session.
        #
        # systemd ships user@.service with OOMScoreAdjust=100, and a
        # process may only *raise* its oom_score_adj without
        # CAP_SYS_RESOURCE. The per-user manager runs unprivileged, so
        # 100 becomes a hard floor for every unit inside the session: a
        # user-level unit asking for anything lower is silently clamped
        # back up, with no error and no log line. Protecting the
        # compositor is therefore impossible from inside the session and
        # has to be done here, where PID 1 applies it with privilege.
        #
        # restartIfChanged, because restarting user@1000.service tears
        # down the running session — precisely the outcome this whole
        # change exists to prevent. The new floor applies at the next
        # login rather than mid-switch.
        "user@" = {
          overrideStrategy = "asDropin";
          restartIfChanged = false;
          serviceConfig.OOMScoreAdjust = -900;
        };
      };

      slices = {
        # ManagedOOMSwap=kill: when swap crosses SwapUsedLimit (90% by
        # default) oomd kills the cgroup with the highest swap usage.
        # This is the earliest trustworthy signal available here — zram
        # is the only swap of consequence and it filled to 100% before
        # every one of the recorded OOM storms, minutes ahead of the
        # kernel's own reaction. The NixOS oomd module only wires up the
        # pressure-based knobs, so set the swap one directly.
        "-".sliceConfig.ManagedOOMSwap = mkDefault "kill";
      };

      timers = {
        shmem-watchdog = {
          timerConfig = {
            OnBootSec = "10min";
            OnUnitActiveSec = "5min";
            Unit = "shmem-watchdog.service";
          };
          wantedBy = [ "timers.target" ];
        };
      };

      user = {
        # Keep applications the preferred OOM victims.
        #
        # This must be stated explicitly rather than left at the default.
        # When DefaultOOMScoreAdjust is unset the user manager derives it
        # from its own oom_score_adj, so dropping user@.service to -900
        # above would otherwise drag every application down to roughly
        # -800 with it — protecting chrome and code exactly as much as the
        # compositor and re-creating the original bug in a worse form,
        # with the kernel forced to look at system daemons instead.
        #
        # Pinning it to +300 keeps that separation fixed: applications sit
        # 1200 points above the compositor regardless of what the manager's
        # own value is. Session infrastructure that must not be a first
        # choice opts out individually in the per-shell modules.
        settings.Manager.DefaultOOMScoreAdjust = 300;
      };
    };
  };
}
