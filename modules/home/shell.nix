{ hostProfile, lilyaTheme, pkgs, ... }:

let
  nh = pkgs.lib.getExe pkgs.nh;
  rebuild = pkgs.writeShellScriptBin "rebuild" ''
    export PATH="/run/wrappers/bin:$PATH"
    exec ${nh} os switch ${hostProfile.user.nixosConfigPath} "$@"
  '';
  testbuild = pkgs.writeShellScriptBin "testbuild" ''
    export PATH="/run/wrappers/bin:$PATH"
    exec ${nh} os test ${hostProfile.user.nixosConfigPath} "$@"
  '';
in

{
  home.packages = [
    rebuild
    testbuild
  ];

  # Fish Shell 配置
  programs.fish = {
    enable = true;

    shellAliases = {
      ll = "ls -alh";
      la = "ls -A";
      gs = "git status";
    };
  };

  # Bash Shell 配置
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

  # Git 配置
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

  # Starship Prompt 配置 (声明式)
  programs.starship = {
    enable = true;

    settings = {
      format = "$nix_shell$directory$git_branch$git_status$cmd_duration$line_break$character";

      palette = "noctalia";

      character = {
        success_symbol = "[ ❯](bold lavender)";
        error_symbol = "[ ❯](bold red)";
      };

      directory = {
        style = "bold teal";
        format = "[$path]($style) [$read_only]($read_only_style)";
        truncation_length = 3;
        truncate_to_repo = true;
        read_only = "";
        read_only_style = "red";
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
        style = "bold sky";
        format = "on [$symbol$branch]($style) ";
      };

      git_status = {
        style = "bold rosewater";
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
        style = "bold blue";
        format = "via [$symbol\\($name\\)]($style) ";
      };

      cmd_duration = {
        min_time = 2000;
        style = "bold black";
        format = "took [$duration]($style) ";
      };

      line_break = {
        disabled = false;
      };

      # Active Noctalia palette, exposed with Catppuccin-compatible role names.
      palettes.noctalia = {
        # Standard colors
        blue      = lilyaTheme.palette.terminal.normal.blue;
        red       = lilyaTheme.palette.terminal.normal.red;
        green     = lilyaTheme.palette.terminal.normal.green;
        yellow    = lilyaTheme.palette.terminal.normal.yellow;
        cyan      = lilyaTheme.palette.terminal.normal.cyan;
        magenta   = lilyaTheme.palette.terminal.normal.magenta;
        white     = lilyaTheme.palette.base;
        black     = lilyaTheme.palette.accent;

        # Extended palette (Catppuccin-compatible names)
        rosewater = lilyaTheme.palette.crust;
        flamingo  = lilyaTheme.palette.error;
        pink      = lilyaTheme.palette.tertiary;
        mauve     = lilyaTheme.palette.terminal.normal.magenta;
        maroon    = lilyaTheme.palette.error;
        peach     = lilyaTheme.palette.terminal.normal.yellow;
        teal      = lilyaTheme.palette.terminal.normal.cyan;
        sky       = lilyaTheme.palette.terminal.bright.blue;
        sapphire  = lilyaTheme.palette.terminal.normal.blue;
        lavender  = lilyaTheme.palette.lavender;

        # Text shades
        text      = lilyaTheme.palette.text;
        subtext1  = lilyaTheme.palette.subtext;
        subtext0  = lilyaTheme.palette.terminal.bright.black;

        # Surface shades
        overlay2  = lilyaTheme.palette.overlay;
        overlay1  = lilyaTheme.palette.hover;
        overlay0  = lilyaTheme.palette.crust;
        surface2  = lilyaTheme.palette.mantle;
        surface1  = lilyaTheme.palette.mantle;
        surface0  = lilyaTheme.palette.base;
        base      = lilyaTheme.palette.base;
        mantle    = lilyaTheme.palette.mantle;
        crust     = lilyaTheme.palette.crust;
      };
    };
  };

}
