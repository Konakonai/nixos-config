{ lilyaGlass, pkgs, ... }:

{
  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.lilya.plasma-overdose-theme;
    name = lilyaGlass.cursorThemeName;
    size = lilyaGlass.cursorSize;
  };
}
