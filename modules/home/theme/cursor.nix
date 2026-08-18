{ lilyaGlass, pkgs, ... }:

{
  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.colloid-cursors;
    name = lilyaGlass.cursorThemeName;
    size = lilyaGlass.cursorSize;
  };
}
