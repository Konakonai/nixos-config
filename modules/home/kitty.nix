{ lilyaTheme, ... }:

{
  # Kitty 终端配置
  programs.kitty = {
    enable = true;

    font = {
      name = lilyaTheme.fonts.mono;
      size = lilyaTheme.fonts.terminalSize;
    };

    settings = {
      confirm_os_window_close = 0;
      enable_audio_bell = false;
      linux_display_server = "wayland";

      # Keep terminal content fully opaque and independent of the wallpaper.
      background_opacity = lilyaTheme.opacity.terminal;
      window_padding_width = 16;

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

      # Terminal Colors & Theme Tokens
      color0 = lilyaTheme.palette.terminal.normal.black;
      color1 = lilyaTheme.palette.terminal.normal.red;
      color2 = lilyaTheme.palette.terminal.normal.green;
      color3 = lilyaTheme.palette.terminal.normal.yellow;
      color4 = lilyaTheme.palette.terminal.normal.blue;
      color5 = lilyaTheme.palette.terminal.normal.magenta;
      color6 = lilyaTheme.palette.terminal.normal.cyan;
      color7 = lilyaTheme.palette.terminal.normal.white;
      color8 = lilyaTheme.palette.terminal.bright.black;
      color9 = lilyaTheme.palette.terminal.bright.red;
      color10 = lilyaTheme.palette.terminal.bright.green;
      color11 = lilyaTheme.palette.terminal.bright.yellow;
      color12 = lilyaTheme.palette.terminal.bright.blue;
      color13 = lilyaTheme.palette.terminal.bright.magenta;
      color14 = lilyaTheme.palette.terminal.bright.cyan;
      color15 = lilyaTheme.palette.terminal.bright.white;

      cursor = lilyaTheme.palette.terminal.cursor;
      cursor_text_color = lilyaTheme.palette.terminal.cursorText;
      background = lilyaTheme.palette.terminal.background;
      foreground = lilyaTheme.palette.terminal.foreground;
      selection_foreground = lilyaTheme.palette.terminal.selectionFg;
      selection_background = lilyaTheme.palette.terminal.selectionBg;
      active_border_color = lilyaTheme.palette.accent;
      inactive_border_color = lilyaTheme.palette.mantle;
      url_color = lilyaTheme.palette.accent;

      active_tab_foreground = "#ffffff";
      active_tab_background = lilyaTheme.palette.accent;
      inactive_tab_foreground = lilyaTheme.palette.subtext;
      inactive_tab_background = lilyaTheme.palette.mantle;
      cursor_trail_color = lilyaTheme.palette.subtext;
    };

    extraConfig = ''
      envinclude KITTY_CONF_*
      # Noctalia's kitty template renders the active palette here.
      include themes/noctalia.conf
    '';
  };
}
