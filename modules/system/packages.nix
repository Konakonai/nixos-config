{ pkgs, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
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

    lilya.cc-switch-cli
    lilya.codex

    unstable.officecli

    qadwaitadecorations-qt6
    kdePackages.dolphin
    kdePackages.kio-fuse
    kdePackages.kservice
    qt6Packages.qt6ct
    opencode
  ];
}
