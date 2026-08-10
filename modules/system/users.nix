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
  config = {
    documentation = {
      doc = {
        enable = mkDefault false;
      };
      enable = mkDefault false;
      man = {
        enable = mkDefault false;
      };
      nixos = {
        enable = mkDefault false;
      };
    };

    environment = {
      # NixOS installs perl, rsync and strace on every system by default. This
      # is a desktop provisioned through the software centre, not a box anyone
      # is meant to debug over SSH, and perl alone is 104 MB — kept alive until
      # now mostly by the full git package that users.nix no longer uses.
      # Anything that genuinely needs one of these still gets it as a
      # dependency; this only stops them being installed unconditionally.
      defaultPackages = mkDefault [ ];
      shells = with pkgs; [
        bash
        nushell
      ];
    };

    i18n = {
      defaultLocale = cfg.locale;
      # Build the locale archive for the locales this system actually selects
      # rather than for all ~500 of them. The full archive is 222 MB and is
      # pulled into every system closure through LOCALE_ARCHIVE; the trimmed
      # one is a few MB.
      #
      # C.UTF-8 is listed alongside the configured locale because systemd units
      # and build tooling fall back to it, and a locale that is not in the
      # archive silently degrades to C/POSIX collation.
      #
      # This is one of the few changes here that costs a local build: the
      # override is a cache miss, so glibc-locales compiles on the machine once
      # per glibc bump. It is minutes, not hours, and it is bounded.
      supportedLocales = mkDefault [
        "C.UTF-8/UTF-8"
        "${cfg.locale}/UTF-8"
      ];
    };

    programs = {
      git = {
        config = {
          safe = {
            directory = [ "/etc/nixos" ];
          };
        };
        enable = true;
        # git is enabled for exactly one reason — the safe.directory line above,
        # so that root-owned /etc/nixos does not trip git's ownership check
        # during nixos-rebuild. The full package is 384 MB and carries Perl
        # (send-email, svn, cvsimport), Tcl/Tk for gitk and git-gui, and ~16 MB
        # of HTML documentation, none of which anything here invokes.
        #
        # nix.nix names git in three more places (the upgrade script's
        # runtimeInputs and two unit `path`s); those use gitMinimal too, or the
        # full package comes back in through the closure and this saves nothing.
        package = mkDefault pkgs.gitMinimal;
      };
    };

    security = {
      pam = {
        services = {
          login = {
            enableGnomeKeyring = mkDefault true;
          };
        };
      };
      polkit = {
        enable = mkDefault true;
        enablePkexecWrapper = mkDefault true;
      };
      rtkit = {
        enable = mkDefault true;
      };
      tpm2 = {
        enable = mkDefault true;
      };
    };

    time = {
      timeZone = cfg.timeZone;
    };

    users = {
      defaultUserShell = pkgs.nushell;
      users = {
        ${cfg.username} = {
          extraGroups = [
            "input"
            "networkmanager"
            "wheel"
          ];
          initialPassword = cfg.initialPassword;
          isNormalUser = true;
          useDefaultShell = true;
        };
      };
    };
  };
}
