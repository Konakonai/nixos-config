{ lilyaTheme, pkgs, ... }:

let
  inherit (lilyaTheme) palette;
  inherit (palette) terminal;

  logoSvg = ../../assets/fastfetch-nixos-logo.svg;
  logoPng =
    pkgs.runCommand "fastfetch-nixos-logomark.png"
      {
        nativeBuildInputs = [ pkgs.resvg ];
      }
      ''
        resvg -w 640 ${logoSvg} $out
      '';
in
{
  # Fish & Bash shells
  programs.fish = {
    enable = true;

    shellAliases = {
      ll = "ls -alh";
      la = "ls -A";
      gs = "git status";
    };
  };

  programs.bash = {
    enable = true;

    shellAliases = {
      ll = "ls -alh";
      la = "ls -A";
      gs = "git status";
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Git
  programs.git = {
    enable = true;

    settings = {
      init.defaultBranch = "main";
      core.autocrlf = "input";
      pull.rebase = true;
      push.autoSetupRemote = true;
      diff.algorithm = "histogram";
      merge.conflictstyle = "zdiff3";
      rerere.enabled = true;
      branch.sort = "-committerdate";
    };
  };

  # Starship prompt
  programs.starship = {
    enable = true;

    settings = {
      format = "$nix_shell$directory$git_branch$git_status$cmd_duration$line_break$character";

      character = {
        success_symbol = "[ ❯](bold ${palette.lavender})";
        error_symbol = "[ ❯](bold ${terminal.normal.red})";
      };

      directory = {
        style = "bold ${terminal.normal.cyan}";
        format = "[$path]($style) [$read_only]($read_only_style)";
        truncation_length = 3;
        truncate_to_repo = true;
        read_only = "";
        read_only_style = terminal.normal.red;
      };

      directory.substitutions = {
        "Documents" = "󱔗 Documents";
        "Downloads" = " Downloads";
        "Music" = "󰎆 Music";
        "Pictures" = " Pictures";
        "Projects" = "󱂚 Projects";
      };

      git_branch = {
        symbol = " ";
        style = "bold ${terminal.bright.blue}";
        format = "on [$symbol$branch]($style) ";
      };

      git_status = {
        style = "bold ${palette.tertiary}";
        format = "[($all_status$ahead_behind)]($style) ";
        conflicted = "=";
        ahead = "⇡";
        behind = "⇣";
        diverged = "⇕";
        untracked = "?";
        modified = "!";
        staged = "+";
        renamed = "»";
        deleted = "✘";
      };

      nix_shell = {
        symbol = " ";
        style = "bold ${terminal.normal.blue}";
        format = "via [$symbol\\($name\\)]($style) ";
      };

      cmd_duration = {
        min_time = 2000;
        style = "bold ${palette.accent}";
        format = "took [$duration]($style) ";
      };

      line_break = {
        disabled = false;
      };
    };
  };

  # Kitty terminal
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
      background_opacity = "1.0";
      window_padding_width = 16;

      modify_font = "cell_height 115%";

      cursor_shape = "block";
      cursor_trail = 1;
      cursor_trail_decay = "0.1 0.3";

      scrollback_lines = 10000;
      scrollback_pager = "less --chop-long-lines --RAW-CONTROL-CHARS +INPUT_LINE_NUMBER";

      tab_bar_edge = "bottom";
      tab_bar_style = "powerline";
      tab_powerline_style = "round";
      tab_bar_min_tabs = 1;
      tab_bar_margin_height = "0 0";

      url_style = "curly";
      open_url_with = "zen-beta";
    };

    # Colors come only from Noctalia's kitty template: it is included last, so
    # any palette set in `settings` above would be overridden anyway.
    extraConfig = ''
      envinclude KITTY_CONF_*
      include themes/noctalia.conf
    '';
  };

  # Fastfetch
  xdg.configFile."fastfetch/config.jsonc".text = builtins.toJSON {
    "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/master/doc/json_schema.json";

    logo = {
      type = "kitty-direct";
      source = "${logoPng}";
      width = 48;
      height = 18;
      preserveAspectRatio = true;
      padding = {
        top = 0;
        right = 4;
      };
    };

    display = {
      separator = "  ";
      brightColor = true;
      color = {
        keys = "blue";
        title = "cyan";
        separator = "blue";
      };
      key = {
        width = 14;
      };
      constants = [
        "fg:${lilyaTheme.palette.text}"
        "accent:${lilyaTheme.palette.accent}"
      ];
    };

    modules = [
      {
        type = "title";
        format = "{user-name-colored}{at-symbol-colored}{host-name-colored}";
      }
      {
        type = "separator";
        string = "┄";
        times = 22;
        outputColor = "blue";
      }
      {
        type = "os";
        key = "╭ OS";
      }
      {
        type = "host";
        key = "├ Host";
      }
      {
        type = "kernel";
        key = "├ Kernel";
      }
      {
        type = "uptime";
        key = "├ Uptime";
      }
      {
        type = "packages";
        key = "╰ Packages";
        combined = false;
        disabled = [ "winget" ];
      }
      {
        type = "separator";
        string = "┄";
        times = 22;
        outputColor = "blue";
      }
      {
        type = "wm";
        key = "╭ WM";
      }
      {
        type = "display";
        key = "├ Displays";
        compactType = "original";
      }
      {
        type = "theme";
        key = "├ Theme";
      }
      {
        type = "terminal";
        key = "├ Terminal";
      }
      {
        type = "shell";
        key = "╰ Shell";
      }
      {
        type = "separator";
        string = "┄";
        times = 22;
        outputColor = "blue";
      }
      {
        type = "cpu";
        key = "╭ CPU";
      }
      {
        type = "gpu";
        key = "├ GPU";
      }
      {
        type = "memory";
        key = "├ Memory";
        format = "{used} / {total} ({percentage})";
      }
      {
        type = "swap";
        key = "├ Swap";
        format = "{used} / {total} ({percentage})";
      }
      {
        type = "disk";
        key = "├ Root";
        folders = "/";
        format = "{size-used} / {size-total} ({size-percentage}) - {filesystem}";
      }
      {
        type = "localip";
        key = "╰ Network";
        compact = true;
      }
    ];
  };
}
