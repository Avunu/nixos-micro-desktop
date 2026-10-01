{
  description = "NixOS Micro Desktop";

  # The project's binary cache, filled by .github/workflows/ci.yml with what
  # cache.nixos.org cannot serve (the patched fcitx5, the trimmed firmware,
  # the system derivations). Nix asks before honouring a flake's `nixConfig`
  # — `accept-flake-config`, answering yes the first time, or
  # `--accept-flake-config` — and everyone else gets a warning and a local
  # build, which is fine. That friction is the correct amount for "this flake
  # would like to add a party who can sign store paths". Same key as
  # modules/system/nix.nix; keep them equal.
  nixConfig = {
    extra-substituters = [ "https://nixos-micro-desktop.cachix.org" ];
    extra-trusted-public-keys = [
      "nixos-micro-desktop.cachix.org-1:Azi3atXTHyECtU/pvC6nvWDoF1BeTuczu8RT3+Yt7ds="
    ];
  };

  inputs = {
    disko = {
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:nix-community/disko";
    };
    nix-packagekit = {
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:Avunu/nix-profile-packagekit-backend";
    };
    nixos-install-helper = {
      inputs = {
        disko.follows = "disko";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:Avunu/nixos-install-helper";
    };
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };
  };

  outputs =
    { nixpkgs, self, ... }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";

      # Public-facing installer: derives its menu from microDesktop.* and ships
      # unattended / guided ISOs plus a nixos-anywhere deploy. The whole
      # installer surface is this one call. microDesktop.desktopShell is an
      # enum, so it shows up in the wizard as a choice automatically.
      ih = inputs.nixos-install-helper.lib.mkProject {
        diskName = "main";
        flakeStyle = "local";
        hints = {
          diskDevice = "disk-device";
        };
        installModules = [ self.nixosModules.microDesktop ];
        inherit nixpkgs self system;
        optionRoots = [ "microDesktop" ];
        upstream = "github:Avunu/nixos-micro-desktop";
      };
    in
    {
      # ── Installer (via nixos-install-helper) ─────────────────────────────────
      # install / installTemplate systems, the unattended + guided ISOs, and the
      # configure / install / deploy apps — all derived from microDesktop.*.
      apps = ih.apps;

      devShells = {
        x86_64-linux = {
          default =
            let
              pkgs = nixpkgs.legacyPackages.x86_64-linux;
            in
            pkgs.mkShell {
              nativeBuildInputs = [
                (pkgs.writeShellScriptBin "update-flake" ''
                  git pull
                  nix flake update
                  git add flake.lock
                  git commit -m "chore: update flake"
                  git push
                '')
              ];
              packages = [
                pkgs.mcp-nixos
              ];
            };
        };
      };

      nixosConfigurations = ih.nixosConfigurations;

      # The desktop itself lives in ./modules — see modules/default.nix for the
      # import list and modules/options.nix for the microDesktop.* surface.
      # Everything here is what needs flake inputs in scope.
      nixosModules = {
        microDesktop = {
          imports = [
            inputs.disko.nixosModules.disko
            inputs.nix-packagekit.nixosModules.default
            ./modules
          ];
        };
      };

      packages = ih.packages;
    };
}
