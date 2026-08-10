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
  config = mkIf (cfg.desktopShell == "noctalia") {
    # Noctalia and its greeter both come from nixpkgs (cache.nixos.org), so no
    # extra flake inputs are needed. `pkgs.noctalia` currently tracks a v5 beta.
    programs = {
      noctalia = {
        enable = mkDefault true;
        systemd = {
          enable = mkDefault true;
          target = "graphical-session.target";
        };
      };
    };

    # nixpkgs packages noctalia-greeter but ships no NixOS module for it, so
    # wire it up here. The package provides bin/noctalia-greeter-session and a
    # polkit action for `noctalia msg greeter-sync`, which is picked up from
    # /run/current-system/sw/share/polkit-1/actions once the package is in
    # systemPackages (the polkit module links /share/polkit-1).
    #
    # Unlike the DMS greeter, this one bundles its own wlroots compositor and
    # so does not launch through niri.
    environment = {
      systemPackages = [ pkgs.noctalia-greeter ];
    };

    services = {
      greetd = {
        settings = {
          default_session = {
            command = "${getExe pkgs.noctalia-greeter} --";
          };
        };
      };
    };

    systemd = {
      user = {
        services = {
          # Noctalia is the default shell but, unlike dms.service, carried no
          # unit configuration at all. It needs the same two protections DMS
          # has, for the same reasons.
          #
          # ManagedOOMPreference=omit takes it out of systemd-oomd's candidate
          # set. system/memory.nix pins applications to +300 and runs oomd
          # across the user slices precisely so a runaway app is chosen first;
          # the shell is session infrastructure rather than an application, and
          # memory.nix leaves it to the per-shell modules to say so.
          #
          # The StartLimit widening matters because Noctalia is the
          # ext-session-lock client. systemd's default of 5 starts per 10s is
          # easy to exceed, and once exceeded systemd stops restarting the unit
          # for good — with the session locked, the compositor is then required
          # to keep every output blanked and there is no way back in. A lock
          # client must never be allowed to give up; 30 per 5 min still catches
          # a genuine instant crash loop.
          #
          # No MemoryHigh/MemoryMax here, deliberately: the caps on dms.service
          # exist because DMS has a measured lock-screen leak. Noctalia has no
          # such measurement behind it, and a ceiling picked without one is
          # just a number that will eventually kill a working session.
          noctalia = {
            overrideStrategy = "asDropin";
            serviceConfig = {
              CPUWeight = 200;
              IOWeight = 200;
              ManagedOOMPreference = "omit";
            };
            unitConfig = {
              StartLimitBurst = 30;
              StartLimitIntervalSec = 300;
            };
          };
        };
      };

      tmpfiles = {
        # Upstream ships lib/tmpfiles.d/noctalia-greeter.conf for this, but only
        # from greeter 1.1.0 — the version in nixpkgs does not have it yet, and
        # systemd.tmpfiles.packages hard-errors on a package with no drop-in.
        # Declaring the state dir directly works on either version. greetd's
        # module creates the greeter user/group this is owned by.
        settings = {
          "10-noctalia-greeter" = {
            "/var/lib/noctalia-greeter" = {
              d = {
                group = "greeter";
                mode = "0750";
                user = "greeter";
              };
            };
          };
        };
      };
    };
  };
}
