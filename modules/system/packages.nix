{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    openlist
    vlc
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

    appimage-run
    xwayland-satellite
    brightnessctl
    imagemagick

    (callPackage ../../pkgs/cc-switch-cli/default.nix {})
    (callPackage ../../pkgs/codex.nix {})

    libsForQt5.qtstyleplugin-kvantum
    kdePackages.qtstyleplugin-kvantum
    nordzy-cursor-theme
    opencode
  ];
}
