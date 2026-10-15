{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    wget
    curl
    openlist
    lilya.celluloid-gl
    rclone
    git
    pciutils
    usbutils
    ripgrep
    fd
    jq
    tree
    unzip
    killall
    btop
    fastfetch
    bubblewrap

    xwayland-satellite
    brightnessctl
    imagemagick

    lilya.codex
    officecli

    adwaita-icon-theme
    qadwaitadecorations-qt6
    kdePackages.dolphin
    # Dolphin's embedded terminal panel is a KonsolePart plugin. External
    # "Open Terminal" actions still use Kitty via kdeglobals.
    kdePackages.konsole
    kdePackages.kio-fuse
    kdePackages.kservice
    qt6Packages.qt6ct
  ];
}
