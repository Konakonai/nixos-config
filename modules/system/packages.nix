{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    vim
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
    p7zip
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
    tela-icon-theme
    lilya.mactahoe-kde
    qadwaitadecorations-qt6
    kdePackages.dolphin
    # Dolphin's embedded terminal panel is a KonsolePart plugin. External
    # "Open Terminal" actions still use Kitty via kdeglobals.
    kdePackages.konsole
    kdePackages.kio-fuse
    kdePackages.kservice
    qt6Packages.qt6ct
    opencode
  ];
}
