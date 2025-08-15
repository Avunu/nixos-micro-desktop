{
  disko.devices = {
    disk = {
      main = {
        device = mkDefault "/dev/sda";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "noatime"
                  "umask=0077"
                ];
                extraArgs = [
                  "-n"
                  "ESP"
                ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "f2fs";
                mountpoint = "/";
                mountOptions = [
                  "noatime"
                  "compress_algorithm=zstd"
                  "compress_mode=default"
                  "compress_force"
                ];
                extraArgs = [
                  "-l"
                  "root"
                ];
              };
            };
          };
        };
      };
    };
  };
}
