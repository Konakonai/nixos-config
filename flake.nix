{
  description = "lilya NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Not used by this flake directly: pkgs/codex-desktop.nix calls the
    # non-flake codex-desktop-linux outputs with it.
    flake-utils.url = "github:numtide/flake-utils";

    pi = {
      url = "github:earendil-works/pi/stable";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-darwin-x64.follows = "nixpkgs";
    };
    nix-flatpak.url = "git+https://github.com/gmodena/nix-flatpak.git?ref=refs/tags/v0.7.0";

    agenix = {
      url = "https://github.com/ryantm/agenix/archive/b027ee29d959fda4b60b57566d64c98a202e0feb.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    codex-desktop-linux = {
      url = "github:ilysenko/codex-desktop-linux";
      flake = false;
    };

    # Unofficial repackage. Unlike aaddrick's, the Nix path consumes a prebuilt
    # tarball from the maintainer's releases rather than patching Anthropic's
    # .deb locally — release assets are immutable, so a pinned tag stays
    # byte-identical. Chosen for its Linux Computer Use bridges (wlroots-bridge
    # covers niri).
    claude-desktop = {
      url = "github:patrickjaja/claude-desktop-extra";
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

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      niri,
      millennium,
      agenix,
      ...
    }:
    let
      hostProfile = import ./hosts/lilya-thinkbook;
      lilyaTheme = import ./modules/shared/theme-settings.nix;
    in
    rec {
      checks.x86_64-linux = import ./checks {
        inherit (nixosConfigurations.nixos) pkgs config;
        inherit hostProfile;
      };

      # Local packages, exposed so `nix-update --flake <name>` can bump the
      # hand-pinned binaries (see README).
      packages.x86_64-linux = nixpkgs.lib.filterAttrs (
        _: nixpkgs.lib.isDerivation
      ) nixosConfigurations.nixos.pkgs.lilya;

      formatter.x86_64-linux = nixosConfigurations.nixos.pkgs.nixfmt-tree;

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
                colloid-icon-theme = final.callPackage ./pkgs/colloid-icon-theme.nix {
                  colloid-icon-theme = prev.colloid-icon-theme;
                };
                lilya = import ./pkgs {
                  pkgs = final;
                  inherit inputs;
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
