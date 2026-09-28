{ pkgs, ... }:

{
  home.packages = with pkgs; [
    chromium
    lilya.brave-origin
  ];
}
