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
    # extra flake inputs are needed. `pkgs.noctalia` currently tracks a v5 beta;
    # see microDesktop.desktopShell for why `dms` remains the default.
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
