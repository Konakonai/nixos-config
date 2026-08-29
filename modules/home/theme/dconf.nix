{ lilyaTheme, ... }:

{
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-light";
    cursor-size = lilyaTheme.cursorSize;
    cursor-theme = lilyaTheme.cursorThemeName;
    font-name = "${lilyaTheme.fonts.sans} ${builtins.toString lilyaTheme.fonts.size}";
    gtk-theme = lilyaTheme.theme.gtk;
    icon-theme = lilyaTheme.iconThemeName;
    monospace-font-name = "${lilyaTheme.fonts.mono} ${builtins.toString lilyaTheme.fonts.size}";
    toolkit-accessibility = true;
  };

  dconf.settings."org/gnome/desktop/sound".theme-name = lilyaTheme.theme.sound;

  dconf.settings."org/gnome/desktop/wm/preferences".button-layout = ":minimize,maximize,close";
}
