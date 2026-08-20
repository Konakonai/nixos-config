{
  palette = {
    accent = "#babbf1"; # Lavender
    lavender = "#babbf1";
    tertiary = "#8caaee"; # Blue
    error = "#e78284"; # Red
    text = "#c6d0f5";
    subtext = "#a5adce";
    base = "#303446";
    mantle = "#292c3c";
    crust = "#232634";
    overlay = "#737994";
    hover = "#414559";
    onHover = "#c6d0f5";
    shadow = "#23263466";
    terminal = {
      background = "#303446";
      foreground = "#c6d0f5";
      cursor = "#babbf1";
      cursorText = "#303446";
      selectionBg = "#51576d";
      selectionFg = "#c6d0f5";
      normal = {
        black = "#414559";
        red = "#e78284";
        green = "#a6d189";
        yellow = "#e5c890";
        blue = "#8caaee";
        magenta = "#ca9ee6";
        cyan = "#81c8be";
        white = "#c6d0f5";
      };
      bright = {
        black = "#51576d";
        red = "#e78284";
        green = "#a6d189";
        yellow = "#e5c890";
        blue = "#8caaee";
        magenta = "#ca9ee6";
        cyan = "#81c8be";
        white = "#b5bfe2";
      };
    };
  };

  opacity = {
    windows = "1.0";
    terminal = "1.0";
    noctaliaPanels = "0.85";
    noctaliaPopups = 0.90;
    noctaliaCapsules = 0.40;
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
    windows = 12.0;
    panels = 16;
    capsules = 12.0;
  };

  iconThemeName = "Papirus-Dark";
  cursorThemeName = "catppuccin-frappe-lavender-cursors";
  cursorSize = 24;

  fonts = {
    sans = "Noto Sans CJK SC";
    serif = "Noto Serif CJK SC";
    mono = "JetBrains Maple Mono";
    size = 11;
    terminalSize = 12;
  };
}
