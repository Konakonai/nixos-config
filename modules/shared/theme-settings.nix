let
  catppuccinLavenderLight =
    (builtins.fromJSON (
      builtins.readFile ../../assets/noctalia/palettes/catppuccin-lavender-light.json
    )).light;
in
{
  # Appearance values read by more than one module. A value only one module
  # uses lives in that module. Noctalia renders the palette into GTK, Qt, niri
  # and kitty at runtime; `palette` here is for the few consumers it does not
  # template (Starship, fastfetch, niri's focus ring and shadow, fcitx5).
  theme = {
    gtk = "adw-gtk3";
    qtStyle = "klassy";
    sound = "ocean";
  };

  palette = {
    accent = catppuccinLavenderLight.mPrimary;
    lavender = catppuccinLavenderLight.mSecondary;
    tertiary = catppuccinLavenderLight.mTertiary;
    text = catppuccinLavenderLight.mOnSurface;
    crust = catppuccinLavenderLight.mShadow;
    shadow = "${catppuccinLavenderLight.mPrimary}29";
    inherit (catppuccinLavenderLight) terminal;
  };

  radius.windows = 14.0;

  iconThemeName = "Colloid-Light";
  cursorThemeName = "catppuccin-frappe-lavender-cursors";
  cursorSize = 32;

  fonts = {
    sans = "Noto Sans CJK SC";
    serif = "Noto Serif CJK SC";
    mono = "JetBrains Maple Mono";
    size = 11;
    terminalSize = 12;
  };
}
