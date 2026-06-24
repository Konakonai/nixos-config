{ pkgs, ... }:

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

    appimage-run
    xwayland-satellite
    brightnessctl
    imagemagick

    (callPackage ../../pkgs/cc-switch-cli/default.nix {})
    (callPackage ../../pkgs/codex.nix {})

    darkly
    qadwaitadecorations-qt6
    qt6Packages.qt6ct
    nordzy-cursor-theme
    opencode
  ];
}
