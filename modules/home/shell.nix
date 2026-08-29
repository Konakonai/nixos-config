{ hostProfile, lilyaGlass, pkgs, ... }:

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
        blue      = lilyaGlass.palette.terminal.normal.blue;
        red       = lilyaGlass.palette.terminal.normal.red;
        green     = lilyaGlass.palette.terminal.normal.green;
        yellow    = lilyaGlass.palette.terminal.normal.yellow;
        cyan      = lilyaGlass.palette.terminal.normal.cyan;
        magenta   = lilyaGlass.palette.terminal.normal.magenta;
        white     = lilyaGlass.palette.base;
        black     = lilyaGlass.palette.accent;

        # Extended palette (Catppuccin-compatible names)
        rosewater = lilyaGlass.palette.crust;
        flamingo  = lilyaGlass.palette.error;
        pink      = lilyaGlass.palette.tertiary;
        mauve     = lilyaGlass.palette.terminal.normal.magenta;
        maroon    = lilyaGlass.palette.error;
        peach     = lilyaGlass.palette.terminal.normal.yellow;
        teal      = lilyaGlass.palette.terminal.normal.cyan;
        sky       = lilyaGlass.palette.terminal.bright.blue;
        sapphire  = lilyaGlass.palette.terminal.normal.blue;
        lavender  = lilyaGlass.palette.lavender;

        # Text shades
        text      = lilyaGlass.palette.text;
        subtext1  = lilyaGlass.palette.subtext;
        subtext0  = lilyaGlass.palette.terminal.bright.black;

        # Surface shades
        overlay2  = lilyaGlass.palette.overlay;
        overlay1  = lilyaGlass.palette.hover;
        overlay0  = lilyaGlass.palette.crust;
        surface2  = lilyaGlass.palette.mantle;
        surface1  = lilyaGlass.palette.mantle;
        surface0  = lilyaGlass.palette.base;
        base      = lilyaGlass.palette.base;
        mantle    = lilyaGlass.palette.mantle;
        crust     = lilyaGlass.palette.crust;
      };
    };
  };

}
