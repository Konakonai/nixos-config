{ pkgs, lib, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  hermesDesktop = import ../../pkgs/hermes-desktop.nix { inherit pkgs lib inputs; };
  unstable = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
in
{
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    openlist
    celluloid
    rclone
    git
    pciutils
    usbutils
    ripgrep
    fd
    jq
    tree
    unzip
    p7zip
    killall
    btop
    fastfetch
    bubblewrap

    xwayland-satellite
    brightnessctl
    imagemagick

    (callPackage ../../pkgs/cc-switch-cli/default.nix {})
    (callPackage ../../pkgs/codex.nix {})

    inputs.hermes-agent.packages.${system}.default
    hermesDesktop
    unstable.officecli

    qadwaitadecorations-qt6
    qt6Packages.qt6ct
    opencode
  ];
}
