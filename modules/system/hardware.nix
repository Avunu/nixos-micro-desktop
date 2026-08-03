{
  lib,
  pkgs,
  ...
}:
with lib;
{
  config = {
    hardware = {
      bluetooth = {
        enable = mkDefault true;
      };
      enableRedistributableFirmware = mkDefault true;
      graphics = {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver
          intel-vaapi-driver
          ocl-icd
          vulkan-loader
        ];
      };
      sane = {
        enable = mkDefault true;
        extraBackends = with pkgs; [
          sane-airscan
          sane-backends
        ];
      };
      sensor = {
        iio = {
          enable = mkDefault true;
        };
      };
    };

    powerManagement = {
      enable = mkDefault true;
      powertop = {
        enable = mkDefault false;
      };
    };

    services = {
      # bpftune dynamically overrides swappiness/watermarks at runtime,
      # which conflicts with zram tuning. Disabled until per-sysctl
      # exclusion is supported upstream.
      bpftune = {
        enable = mkDefault false;
      };
      colord = {
        enable = mkDefault true;
      };
      fprintd = {
        enable = mkDefault true;
        package = mkDefault pkgs.fprintd-tod;
        tod = {
          driver = mkDefault pkgs.libfprint-2-tod1-goodix;
          enable = mkDefault true;
        };
      };
      fstrim = {
        enable = mkDefault true;
        interval = mkDefault "daily";
      };
      fwupd = {
        enable = mkDefault true;
      };
      kmscon = {
        config = {
          hwaccel = mkDefault true;
        };
        enable = mkDefault true;
      };
      libinput = {
        enable = mkDefault true;
      };
      power-profiles-daemon = {
        enable = mkDefault true;
      };
      udisks2 = {
        enable = mkDefault true;
      };
      upower = {
        enable = mkDefault true;
      };
    };
  };
}
