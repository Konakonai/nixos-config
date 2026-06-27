{ pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    chromium
    file-roller
    gnome-font-viewer
    nemo-with-extensions
    pavucontrol
    mission-center
    resources
    foliate
    localsend
    hyprpicker
    loupe
    swappy

    (import ../../pkgs/antigravity.nix { inherit pkgs lib; })
    (import ../../pkgs/splayer.nix { inherit pkgs lib; })
  ];
}
