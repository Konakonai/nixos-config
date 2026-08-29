{ lilyaTheme, pkgs, ... }:

{
  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.catppuccin-cursors.frappeLavender;
    name = lilyaTheme.cursorThemeName;
    size = lilyaTheme.cursorSize;
  };
}
