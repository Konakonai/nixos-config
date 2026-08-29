let
  catppuccinLavenderLight =
    (builtins.fromJSON (
      builtins.readFile ../../assets/noctalia/palettes/catppuccin-lavender-light.json
    )).light;
in
{
  # One explicit source of truth for the active light appearance. Noctalia
  # supplies the palette and generated application colors; native toolkits keep
  # their current light widget styles so application geometry stays reliable.
  theme = {
    paletteName = "Catppuccin Lavender Light";
    mode = "light";
    source = "custom";
    gtk = "adw-gtk3";
    qtStyle = "klassy";
    sound = "ocean";
    plasma = {
      lookAndFeel = "org.kde.breeze.desktop";
      workspace = "default";
      colorScheme = "BreezeLight";
    };
  };

  palette = {
    accent = catppuccinLavenderLight.mPrimary;
    lavender = catppuccinLavenderLight.mSecondary;
    tertiary = catppuccinLavenderLight.mTertiary;
    error = catppuccinLavenderLight.mError;
    text = catppuccinLavenderLight.mOnSurface;
    subtext = catppuccinLavenderLight.mOnSurfaceVariant;
    base = catppuccinLavenderLight.mSurface;
    mantle = catppuccinLavenderLight.mSurfaceVariant;
    crust = catppuccinLavenderLight.mShadow;
    overlay = catppuccinLavenderLight.mOutline;
    hover = catppuccinLavenderLight.mHover;
    onHover = catppuccinLavenderLight.mOnHover;
    shadow = "${catppuccinLavenderLight.mPrimary}29";
    inherit (catppuccinLavenderLight) terminal;
  };

  # Material 3-inspired surface hierarchy. The shell chrome is absent, while
  # content surfaces stay fully opaque and do not rely on backdrop blur.
  opacity = {
    terminal = "1.0";
    noctaliaPanels = 0.0;
    noctaliaDock = 0.0;
    noctaliaPopups = 1.0;
    plasmaPanel = "opaque";
    plasmaTitlebarActive = 100;
    plasmaTitlebarInactive = 100;
    modalBackdrop = 0.48;
    disabled = 0.68;
  };

  effects = {
    backgroundBlur = false;
    backdropBlur = 0.0;
    backdropTint = 0.0;
    lockscreenBlur = 0.0;
    lockscreenTint = 0.0;
  };

  shadow = {
    alpha = 0.16;
  };

  noctalia = {
    panelTransparencyMode = "solid";
  };

  radius = {
    windows = 14.0;
    panels = 22;
  };

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
