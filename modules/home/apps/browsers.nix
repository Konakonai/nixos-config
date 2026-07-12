{ pkgs, ... }:

{
  home.packages = with pkgs; [
    chromium
    lilya.brave-origin
    lilya.brave-netflix-opera
  ];
}
