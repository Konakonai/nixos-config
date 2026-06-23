{ pkgs, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  unstable = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
in
{
  home.packages = with pkgs; [
    aria2
    chromium
    mpv
    python3Packages.ddgs

    inputs.hermes-agent.packages.${system}.default
    unstable.officecli
  ];
}
