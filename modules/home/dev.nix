{ pkgs, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  unstable = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
in
{
  programs.gh.enable = true;

  home.packages = with pkgs; [
    gcc
    rustup
    go
    nodejs
    python3
    lua
    git-lfs

    inputs.hermes-agent.packages.${system}.default
    unstable.officecli
  ];
}
