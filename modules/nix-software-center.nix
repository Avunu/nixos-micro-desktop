# NixOS module to enable native Nix package management in GNOME Software
# This provides the AppStream catalog data that GNOME Software needs to browse packages
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.nix-software-center;
  
  # Fetch pre-built AppStream data from snowfallorg
  # This contains package metadata, categories, icons, screenshots
  nixos-appstream-data = pkgs.stdenv.mkDerivation rec {
    pname = "nixos-appstream-data";
    version = "unstable-2025-01-02";
    
    src = pkgs.fetchFromGitHub {
      owner = "snowfallorg";
      repo = "nixos-appstream-data";
      rev = "master";  # Or pin to a specific commit
      sha256 = lib.fakeSha256;  # Will need to update after first build attempt
    };
    
    installPhase = ''
      mkdir -p $out/share/swcatalog/xml
      mkdir -p $out/share/swcatalog/icons/nixos
      
      # Install XML catalog (may be gzipped)
      if [ -d "free/xml" ]; then
        cp -r free/xml/* $out/share/swcatalog/xml/ || true
      fi
      if [ -d "unfree/xml" ]; then
        cp -r unfree/xml/* $out/share/swcatalog/xml/ || true
      fi
      
      # Install icons
      if [ -d "free/icons" ]; then
        cp -r free/icons/* $out/share/swcatalog/icons/nixos/ || true
      fi
      if [ -d "unfree/icons" ]; then
        cp -r unfree/icons/* $out/share/swcatalog/icons/nixos/ || true
      fi
    '';
    
    meta = with lib; {
      description = "AppStream catalog data for nixpkgs";
      homepage = "https://github.com/snowfallorg/nixos-appstream-data";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  };

in {
  options.programs.nix-software-center = {
    enable = lib.mkEnableOption "native Nix package browsing in GNOME Software";
    
    includeUnfree = lib.mkOption {
      type = lib.types.bool;
      default = config.nixpkgs.config.allowUnfree or false;
      description = "Whether to include unfree packages in the catalog";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable PackageKit daemon (includes nix backend when nix libs present)
    services.packagekit.enable = true;
    
    # Ensure appstream support is enabled
    appstream.enable = true;
    
    # Install the AppStream catalog data
    environment.systemPackages = [ nixos-appstream-data ];
    
    # Link catalog to where libappstream looks for it
    environment.pathsToLink = [
      "/share/swcatalog"
      "/share/app-info"
    ];
    
    # Alternative: directly create the symlinks
    system.activationScripts.appstream-catalog = ''
      # Ensure catalog directories exist
      mkdir -p /var/cache/swcatalog/xml
      mkdir -p /var/cache/swcatalog/icons
      
      # Link the catalog data
      ln -sf ${nixos-appstream-data}/share/swcatalog/xml/* /var/cache/swcatalog/xml/ 2>/dev/null || true
      ln -sf ${nixos-appstream-data}/share/swcatalog/icons/* /var/cache/swcatalog/icons/ 2>/dev/null || true
    '';
  };
}
