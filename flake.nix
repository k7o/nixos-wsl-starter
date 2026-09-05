{
  description = "NixOS configuration";

  inputs = {

    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/nixos-wsl/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = inputs:
    with inputs; let
      overlayRegistry = builtins.fromJSON (builtins.readFile ./overlays/registry.json);

      # Custom packages from overlays/registry.json, exposed under a single
      # pkgs.custom.<attribute> namespace (like pkgs.unstable) so a package
      # name can never shadow an identically named nixpkgs attribute.
      customOverlay = final: prev: {
        custom = builtins.listToAttrs (
          builtins.map (
            overlay: {
              name = overlay.attribute;
              value = final.callPackage (./. + "/overlays/${overlay.directory}/package.nix") {};
            }
          ) overlayRegistry.overlays
        );
      };

      nixpkgsWithOverlays = system: (import nixpkgs {
        inherit system;

        config = {
          allowUnfree = true;
          permittedInsecurePackages = [
            # FIXME:: add any insecure packages you absolutely need here
          ];
        };

        overlays = [
          (final: prev: {
            unstable = import nixpkgs-unstable {
              system = prev.stdenv.hostPlatform.system;
              config = prev.config;
            };
          })
          # Note: pkgs.unstable intentionally does not get customOverlay, so
          # pkgs.unstable.custom does not exist.
          customOverlay
        ];
      });

      configurationDefaults = args: {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "hm-backup";
        home-manager.extraSpecialArgs = args;
      };

      argDefaults = {
        inherit inputs self nix-index-database;
        channels = {
          inherit nixpkgs nixpkgs-unstable;
        };
      };

      mkNixosConfiguration = {
        system ? "x86_64-linux",
        hostname,
        username,
        args ? {},
        modules,
      }: let
        specialArgs = argDefaults // {inherit hostname username;} // args;
      in
        nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          pkgs = nixpkgsWithOverlays system;
          modules =
            [
              (configurationDefaults specialArgs)
              home-manager.nixosModules.home-manager
            ]
            ++ modules;
        };
    in {

      nixosConfigurations.nixos = mkNixosConfiguration {
        hostname = "nixos";
        username = "eric";
        modules = [
          nixos-wsl.nixosModules.wsl
          ./wsl.nix
        ];
      };
    };
}
