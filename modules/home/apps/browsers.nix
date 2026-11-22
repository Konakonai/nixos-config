{ pkgs, ... }:

{
  home.packages = with pkgs; [
    chromium
    brave-origin
  ];
}
