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
  # Omit `logo.height` with kitty-direct: setting both columns and rows lets
  # Kitty stretch the PNG across non-square terminal cells instead of preserving
  # the hexagon's 2:sqrt(3) aspect ratio. Keeping width=26 and compact lines
  # also prevents wrapping inside niri's default half-screen column.
  xdg.configFile."fastfetch/config.jsonc".text = builtins.toJSON {
    "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/master/doc/json_schema.json";

    logo = {
      type = "kitty-direct";
      source = "${logoPng}";
      width = 26;
      preserveAspectRatio = true;
      padding = {
        top = 1;
        left = 2;
        right = 3;
      };
    };

    display = {
      separator = "  ";
      key = {
        width = 12;
      };
    };

    modules = [
      {
        type = "title";
        color = {
          user = "magenta";
          at = "cyan";
          host = "blue";
        };
      }
      {
        type = "separator";
        string = "─";
        outputColor = "bright_black";
      }
      {
        type = "os";
        key = "󱄅  OS";
        keyColor = "blue";
        format = "{pretty-name}";
      }
      {
        type = "host";
        key = "󰌢  Host";
        keyColor = "blue";
        format = "{version}";
      }
      {
        type = "kernel";
        key = "  Kernel";
        keyColor = "blue";
        format = "{sysname} {release}";
      }
      {
        type = "uptime";
        key = "󰅐  Uptime";
        keyColor = "blue";
      }
      {
        type = "packages";
        key = "󰏗  Pkgs";
        keyColor = "blue";
        combined = true;
        disabled = [ "winget" ];
      }
      {
        type = "wm";
        key = "  WM";
        keyColor = "cyan";
        format = "{pretty-name} ({protocol-name})";
      }
      {
        type = "display";
        key = "󰍹  Display";
        keyColor = "cyan";
        compactType = "original";
      }
      {
        type = "shell";
        key = "  Shell";
        keyColor = "cyan";
      }
      {
        type = "terminal";
        key = "  Term";
        keyColor = "cyan";
      }
      {
        type = "cpu";
        key = "  CPU";
        keyColor = "magenta";
        format = "{name} ({cores-logical})";
      }
      {
        type = "gpu";
        key = "󰢮  GPU";
        keyColor = "magenta";
        format = "{name}";
      }
      {
        type = "memory";
        key = "  Memory";
        keyColor = "magenta";
        format = "{used} / {total} ({percentage})";
      }
      {
        type = "disk";
        key = "󰋊  Disk";
        keyColor = "magenta";
        folders = "/";
        format = "{size-used} / {size-total} ({size-percentage})";
      }
      {
        type = "localip";
        key = "󰩟  IP";
        keyColor = "magenta";
        compact = true;
      }
      "break"
      {
        type = "colors";
        symbol = "circle";
      }
    ];
  };
}
