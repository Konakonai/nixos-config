{ lilyaGlass, pkgs, ... }:

{
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.rose-pine-cursor;
    name = lilyaGlass.cursorThemeName;
    size = 48;
  };
}
