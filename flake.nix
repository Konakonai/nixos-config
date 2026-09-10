{
  description = "lilya NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-flatpak.url = "git+https://github.com/gmodena/nix-flatpak.git?ref=refs/tags/v0.7.0";

    agenix = {
      url = "https://github.com/ryantm/agenix/archive/b027ee29d959fda4b60b57566d64c98a202e0feb.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    codex-desktop-linux = {
      url = "github:ilysenko/codex-desktop-linux";
      flake = false;
    };

    claude-desktop = {
      url = "github:aaddrick/claude-desktop-debian/v3.2.1+claude1.24012.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake/beta";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    niri = {
      url = "github:epireyn/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    millennium = {
      url = "git+https://github.com/SteamClientHomebrew/Millennium.git?dir=packages/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, niri, noctalia, millennium, plasma-manager, agenix, ... }:
  let
    hostProfile = import ./hosts/lilya-thinkbook;
    lilyaTheme = import ./modules/shared/theme-settings.nix;
  in
  {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      specialArgs = {
        inherit inputs hostProfile lilyaTheme;
      };

      modules = [
        ./configuration.nix

        niri.nixosModules.niri
        agenix.nixosModules.default

        {
          nixpkgs.overlays = [
            millennium.overlays.default
            (final: prev: {
              xwayland-satellite = final.callPackage ./pkgs/xwayland-satellite.nix {
                xwayland-satellite = prev.xwayland-satellite;
              };
              lilya = import ./pkgs {
                pkgs = final;
                lib = final.lib;
              };
            })
          ];
        }

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.overwriteBackup = true;

          home-manager.extraSpecialArgs = {
            inherit inputs hostProfile lilyaTheme;
          };

          home-manager.users.${hostProfile.user.userName} = import ./home.nix;
        }
      ];
    };
  };
}
