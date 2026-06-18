{ config, pkgs, ... }:

let
  lilyaGlass = import ./glass-settings.nix;
in
{
  # Kitty 终端配置
  programs.kitty = {
    enable = true;

    font = {
      name = lilyaGlass.fonts.mono;
      size = lilyaGlass.fonts.terminalSize;
    };

    settings = {
      confirm_os_window_close = 0;
      enable_audio_bell = false;
      linux_display_server = "wayland";

      # Layout & Aesthetics — transparent background without a milky tint.
      background_opacity = lilyaGlass.opacity.terminal;
      window_padding_width = 16;
      hide_window_decorations = "yes";

      # Font Line Height
      modify_font = "cell_height 115%";

      # Cursor
      cursor_shape = "block";
      cursor_trail = 1;
      cursor_trail_decay = "0.1 0.3";

      # Scrollback
      scrollback_lines = 10000;
      scrollback_pager = "less --chop-long-lines --RAW-CONTROL-CHARS +INPUT_LINE_NUMBER";

      # Tab Bar
      tab_bar_edge = "bottom";
      tab_bar_style = "powerline";
      tab_powerline_style = "round";
      tab_bar_min_tabs = 1;
      tab_bar_margin_height = "0 0";

      # URL
      url_style = "curly";
      open_url_with = "zen-beta";

      # Catppuccin Latte (official palette)
      foreground = lilyaGlass.palette.text;
      background = lilyaGlass.palette.base;
      selection_foreground = lilyaGlass.palette.base;
      selection_background = "#dc8a78";
      url_color = "#dc8a78";
      cursor = "#dc8a78";
      cursor_text_color = lilyaGlass.palette.base;

      # Window border
      active_border_color = lilyaGlass.palette.lavender;
      inactive_border_color = lilyaGlass.palette.overlay;
      bell_border_color = "#df8e1d";

      # Tab bar (Catppuccin Latte)
      active_tab_foreground = lilyaGlass.palette.base;
      active_tab_background = lilyaGlass.palette.accent;
      inactive_tab_foreground = lilyaGlass.palette.text;
      inactive_tab_background = lilyaGlass.palette.overlay;
      tab_bar_background = lilyaGlass.palette.crust;

      # Black
      color0 = "#5c5f77";
      color8 = "#6c6f85";

      # Red
      color1 = "#d20f39";
      color9 = "#d20f39";

      # Green
      color2 = "#40a02b";
      color10 = "#40a02b";

      # Yellow
      color3 = "#df8e1d";
      color11 = "#df8e1d";

      # Blue
      color4 = "#7287fd";
      color12 = "#7287fd";

      # Magenta
      color5 = "#ea76cb";
      color13 = "#ea76cb";

      # Cyan
      color6 = "#179299";
      color14 = "#179299";

      # White
      color7 = "#acb0be";
      color15 = "#bcc0cc";
    };
  };
}
