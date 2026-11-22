{ hostProfile, ... }:

{
  imports = [
    # Core system
    ./core/base.nix
    ./core/nix.nix
    ./core/boot.nix
    ./core/graphics.nix
    ./core/networking.nix
    ./core/power.nix
    ./core/usb-c.nix
    ./core/backup.nix
    ./core/virtualization.nix

    # Services (dual-layer where needed)
    ./services/mihomo
    ./services/media.nix
    ./services/nectarlink.nix

    # Desktop (system & dual-layer)
    ./desktop/display/login.nix
    ./desktop/display/edp-link.nix
    ./desktop/display/session.nix
    ./desktop/fonts.nix
    ./desktop/fcitx5.nix

    # User workflows (dual-layer)
    ./user/ai.nix
    ./user/gaming.nix
    ./user/music.nix
  ];

  home-manager.users.${hostProfile.user.userName}.imports = [
    # Desktop (Home Manager)
    ./desktop/niri
    ./desktop/noctalia.nix
    ./desktop/plasma.nix
    ./desktop/theme.nix
    ./desktop/mime.nix

    # User environment & apps (Home Manager)
    ./user/shell.nix
    ./user/nixos-tools.nix
    ./user/packages.nix
    ./user/apps/bitwarden.nix
    ./user/apps/dolphin.nix
    ./user/apps/flatpak.nix
    ./user/apps/foliate.nix
    ./user/apps/libreoffice.nix
    ./user/apps/yazi.nix
    ./user/apps/zed.nix
    ./user/apps/zen.nix
  ];
}
