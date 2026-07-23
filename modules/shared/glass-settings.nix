let
  plasmaOverdose =
    (builtins.fromJSON (
      builtins.readFile ../../assets/noctalia/palettes/plasma-overdose.json
    )).light;
in
{
  palette = {
    accent = plasmaOverdose.mPrimary;
    lavender = plasmaOverdose.mSecondary;
    tertiary = plasmaOverdose.mTertiary;
    error = plasmaOverdose.mError;
    text = plasmaOverdose.mOnSurface;
    subtext = plasmaOverdose.mOnSurfaceVariant;
    base = plasmaOverdose.mSurface;
    mantle = plasmaOverdose.mSurfaceVariant;
    crust = plasmaOverdose.mShadow;
    overlay = plasmaOverdose.mOutline;
    hover = plasmaOverdose.mHover;
    onHover = plasmaOverdose.mOnHover;
    shadow = "${plasmaOverdose.mPrimary}33";
    inherit (plasmaOverdose) terminal;
  };

  opacity = {
    windows = "1.0";
    terminal = "0.84";
    noctaliaPanels = "0.70";
    noctaliaPopups = 0.82;
    noctaliaCapsules = 0.32;
    layerShell = "0.92";
    layerPopups = "0.94";
  };

  blur = {
    passes = 2;
    offset = "2.0";
    noise = "0.0";
    saturation = "1.08";
  };

  noctalia = {
    panelTransparencyMode = "soft";
  };

  radius = {
    windows = 14.0;
    panels = 22;
    capsules = 16.0;
  };

  iconThemeName = "Tela";
  cursorThemeName = "Plasma-Overdose";
  cursorSize = 32;

  fonts = {
    sans = "Noto Sans CJK SC";
    serif = "Noto Serif CJK SC";
    mono = "JetBrains Maple Mono";
    size = 11;
    terminalSize = 12;
  };
}
