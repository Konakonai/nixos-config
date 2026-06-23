{ pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    chromium
    file-roller
    nemo-with-extensions
    mpv
    pavucontrol
    mission-center
    resources
    localsend
    hyprpicker
    swappy

    (import ../../pkgs/antigravity.nix { inherit pkgs lib; })
    (import ../../pkgs/splayer.nix { inherit pkgs lib; })
  ];
}
