{ config, pkgs, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
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

    };

    extraConfig = ''
      include themes/noctalia.conf
    '';
  };
}
