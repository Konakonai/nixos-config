{
  description = "lilya NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
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

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake/beta";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
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
  };

  outputs = inputs@{ nixpkgs, home-manager, niri, noctalia, millennium, agenix, ... }:
  let
    hostProfile = import ./hosts/lilya-thinkbook;
    lilyaGlass = import ./modules/shared/glass-settings.nix;
  in
  {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      specialArgs = {
        inherit inputs hostProfile lilyaGlass;
      };

      modules = [
        ./configuration.nix

        niri.nixosModules.niri
        agenix.nixosModules.default

        {
          nixpkgs.overlays = [
            millennium.overlays.default
          ];
        }

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";

          home-manager.extraSpecialArgs = {
            inherit inputs hostProfile lilyaGlass;
          };

          home-manager.users.${hostProfile.user.userName} = import ./home.nix;
        }
      ];
    };
  };
}
