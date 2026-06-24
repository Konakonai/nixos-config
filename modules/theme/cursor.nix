{ pkgs, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
in
{
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.nordzy-cursor-theme;
    name = lilyaGlass.cursorThemeName;
    size = 48;
  };
}
