{
  config,
  lilyaTheme,
  pkgs,
  ...
}:

{
  # Desktop-independent variables only; home.pointerCursor (cursor.nix) sets
  # XCURSOR_THEME and XCURSOR_SIZE. The Qt platform theme and decoration
  # choices belong to the niri session (modules/home/niri/core.nix); Plasma
  # supplies its own.
  home.sessionVariables = {
    GTK_USE_PORTAL = "1";
    GTK2_RC_FILES = "${config.home.homeDirectory}/.gtkrc-2.0";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    XCURSOR_PATH = "${pkgs.catppuccin-cursors.frappeLavender}/share/icons:${pkgs.adwaita-icon-theme}/share/icons";
  };
}
