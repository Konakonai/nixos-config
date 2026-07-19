{ hostProfile, pkgs, ... }:

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

      # Plasma Overdose palette, matching Noctalia's custom palette.
      palettes.noctalia = {
        # Standard colors
        blue      = "#1d99f3";
        red       = "#da4453";
        green     = "#27ae60";
        yellow    = "#f67400";
        cyan      = "#1abc9c";
        magenta   = "#9b59b6";
        white     = "#fcf0fd";
        black     = "#4d21cb";

        # Extended palette (Catppuccin-compatible names)
        rosewater = "#efcfef";
        flamingo  = "#da4453";
        pink      = "#ff557f";
        mauve     = "#9b59b6";
        maroon    = "#da4453";
        peach     = "#f67400";
        teal      = "#1abc9c";
        sky       = "#55aaff";
        sapphire  = "#1d99f3";
        lavender  = "#712aff";

        # Text shades
        text      = "#4d21cb";
        subtext1  = "#4f22d4";
        subtext0  = "#7b7b7a";

        # Surface shades
        overlay2  = "#a3c6ee";
        overlay1  = "#bed7fc";
        overlay0  = "#efcfef";
        surface2  = "#f6e0f8";
        surface1  = "#f6e0f8";
        surface0  = "#fcf0fd";
        base      = "#fcf0fd";
        mantle    = "#f6e0f8";
        crust     = "#efcfef";
      };
    };
  };

}
