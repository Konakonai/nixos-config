{ lilyaGlass, pkgs, ... }:

{
  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.adwaita-icon-theme;
    name = lilyaGlass.cursorThemeName;
    size = lilyaGlass.cursorSize;
  };
}
