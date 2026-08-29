let
  catppuccinLavenderGlass =
    (builtins.fromJSON (
      builtins.readFile ../../assets/noctalia/palettes/catppuccin-lavender-glass.json
    )).light;
in
{
  # One explicit source of truth for the active light appearance. Noctalia
  # supplies the palette and generated application colors; native toolkits keep
  # their current light widget styles so application geometry stays reliable.
  theme = {
    paletteName = "Catppuccin Lavender Glass";
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
    accent = catppuccinLavenderGlass.mPrimary;
    lavender = catppuccinLavenderGlass.mSecondary;
    tertiary = catppuccinLavenderGlass.mTertiary;
    error = catppuccinLavenderGlass.mError;
    text = catppuccinLavenderGlass.mOnSurface;
    subtext = catppuccinLavenderGlass.mOnSurfaceVariant;
    base = catppuccinLavenderGlass.mSurface;
    mantle = catppuccinLavenderGlass.mSurfaceVariant;
    crust = catppuccinLavenderGlass.mShadow;
    overlay = catppuccinLavenderGlass.mOutline;
    hover = catppuccinLavenderGlass.mHover;
    onHover = catppuccinLavenderGlass.mOnHover;
    shadow = "${catppuccinLavenderGlass.mPrimary}29";
    inherit (catppuccinLavenderGlass) terminal;
  };

  # Modern light glass: keep content opaque, use subtle component-owned alpha,
  # and never multiply it again at the compositor layer.
  opacity = {
    windows = "1.0";
    terminal = "0.96";
    noctaliaPanels = 0.92;
    noctaliaDock = 0.90;
    noctaliaPopups = 0.96;
    noctaliaCapsules = 0.82;
    compositorLayers = "1.0";
    plasmaPanel = "translucent";
    plasmaTitlebarActive = 96;
    plasmaTitlebarInactive = 90;
    modalBackdrop = 0.48;
    disabled = 0.68;
  };

  blur = {
    passes = 3;
    offset = "2.0";
    noise = "0.01";
    saturation = "1.04";
    backdrop = 0.48;
    backdropTint = 0.14;
    lockscreen = 0.55;
    lockscreenTint = 0.22;
    plasmaStrength = 8;
    plasmaNoise = 2;
  };

  shadow = {
    alpha = 0.16;
  };

  noctalia = {
    panelTransparencyMode = "soft";
  };

  radius = {
    windows = 14.0;
    panels = 22;
    capsules = 16.0;
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
