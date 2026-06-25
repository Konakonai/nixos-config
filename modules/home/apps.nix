{ pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    chromium
    file-roller
    nemo-with-extensions
    pavucontrol
    mission-center
    resources
    localsend
    hyprpicker
    satty

    (import ../../pkgs/antigravity.nix { inherit pkgs lib; })
    (import ../../pkgs/splayer.nix { inherit pkgs lib; })
  ];
}
