{
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.microDesktop;
in
{
  config = mkIf (cfg.desktopShell == "dms") {
    programs = {
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
    };

    services = {
      displayManager = {
        dms-greeter = {
          compositor = {
            name = "niri";
          };
          configHome = "/home/${cfg.username}";
          enable = mkDefault true;
        };
      };
    };

    systemd = {
      user = {
        services = {
          # Bound the shell so its leak cannot take the machine with it.
          #
          # DMS's lock screen leaks roughly 2 GiB/minute on a six-output
          # setup. Unlocked it is flat at ~2.1 GiB; an idle machine that
          # locks itself reaches 131 GiB of 134 GiB within the hour, and
          # from there everything else is collateral — PID 1 blocked on
          # btrfs semaphores for six minutes, displays taking minutes to
          # light up, oomd working through the session to claw memory
          # back. Nothing bounded dms.service, so a single leaking QML
          # shell could consume the entire machine.
          #
          # MemorySwapMax matters as much as MemoryMax here: cgroup v2
          # accounts swap separately, so a memory cap on its own does not
          # contain a leak, it converts it into swap thrash. The observed
          # peak was 119.8 GiB resident *plus* 68.9 GiB of swap — capping
          # only the former would have left most of that thrash in place.
          #
          # With this, a leaking shell dies alone every few minutes while
          # locked and restarts in ~1s. That is a visible flicker on the
          # lock screen rather than an unusable workstation, and it holds
          # until the upstream leak is fixed.
          #
          # The start-limit is widened deliberately. dms.service ships
          # with the systemd default of 5 starts per 10s, and once that
          # is exceeded systemd stops restarting it for good. DMS is the
          # ext-session-lock client: if it dies for good while the
          # session is locked, the compositor is required to keep every
          # output blanked and there is no way to unlock — the solid
          # colour on all monitors that made the machine unusable. A
          # session lock client must therefore never be allowed to give
          # up; 30 per 5min still catches a genuine instant crash loop
          # while leaving ample room for leak-driven restarts.
          dms = {
            overrideStrategy = "asDropin";
            serviceConfig = {
              MemoryHigh = "4G";
              MemoryMax = "8G";
              MemorySwapMax = "2G";
            };
            unitConfig = {
              StartLimitBurst = 30;
              StartLimitIntervalSec = 300;
            };
          };
        };
      };
    };
  };
}
