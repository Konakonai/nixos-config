{ lilyaGlass, ... }:

{
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-light";
    cursor-size = lilyaGlass.cursorSize;
    cursor-theme = lilyaGlass.cursorThemeName;
    font-name = "${lilyaGlass.fonts.sans} ${builtins.toString lilyaGlass.fonts.size}";
    gtk-theme = "Plasma-Overdose-GTK";
    icon-theme = lilyaGlass.iconThemeName;
    monospace-font-name = "${lilyaGlass.fonts.mono} ${builtins.toString lilyaGlass.fonts.size}";
    toolkit-accessibility = true;
  };

  # Electron 43 reads this platform preference for its Linux window-controls
  # overlay. niri provides the window actions, so do not reserve client space
  # for minimize, maximize, or close buttons.
  dconf.settings."org/gnome/desktop/wm/preferences".button-layout = ":";
}
