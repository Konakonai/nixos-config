{ config, hostProfile, pkgs, ... }:

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

      # Noctalia Starship Palette (Nord 色系)
      palettes.noctalia = {
        # Standard colors
        blue      = "#81a1c1";
        red       = "#bf616a";
        green     = "#96b17f";
        yellow    = "#c5a565";
        cyan      = "#7bb3c3";
        magenta   = "#b48ead";
        white     = "#a5abb6";
        black     = "#3b4252";

        # Extended palette (Catppuccin-compatible names)
        rosewater = "#c5a565";
        flamingo  = "#bf616a";
        pink      = "#b48ead";
        mauve     = "#b48ead";
        maroon    = "#bf616a";
        peach     = "#c5a565";
        teal      = "#7bb3c3";
        sky       = "#82afae";
        sapphire  = "#81a1c1";
        lavender  = "#b48ead";

        # Text shades
        text      = "#414858";
        subtext1  = "#a5abb6";
        subtext0  = "#4c566a";

        # Surface shades
        overlay2  = "#4c566a";
        overlay1  = "#4c566a";
        overlay0  = "#3b4252";
        surface2  = "#3b4252";
        surface1  = "#3b4252";
        surface0  = "#eceff4";
        base      = "#eceff4";
        mantle    = "#eceff4";
        crust     = "#eceff4";
      };
    };
  };
}
