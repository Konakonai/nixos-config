{ lilyaGlass, ... }:

{
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    cursor-size = lilyaGlass.cursorSize;
    cursor-theme = lilyaGlass.cursorThemeName;
    font-name = "${lilyaGlass.fonts.sans} ${builtins.toString lilyaGlass.fonts.size}";
    gtk-theme = "catppuccin-frappe-lavender-compact";
    icon-theme = lilyaGlass.iconThemeName;
    monospace-font-name = "${lilyaGlass.fonts.mono} ${builtins.toString lilyaGlass.fonts.size}";
    toolkit-accessibility = true;
  };

  dconf.settings."org/gnome/desktop/wm/preferences".button-layout = ":minimize,maximize,close";
}
