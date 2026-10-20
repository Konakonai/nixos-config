{
  hostProfile,
  lilyaTheme,
  pkgs,
  ...
}:

let
  nh = pkgs.lib.getExe pkgs.nh;
  rebuild = pkgs.writeShellScriptBin "rebuild" ''
    export PATH="/run/wrappers/bin:$PATH"
    exec ${nh} os switch ${hostProfile.user.nixosConfigPath} "$@"
  '';
  inherit (lilyaTheme) palette;
  inherit (palette) terminal;
  testbuild = pkgs.writeShellScriptBin "testbuild" ''
    export PATH="/run/wrappers/bin:$PATH"
    exec ${nh} os test ${hostProfile.user.nixosConfigPath} "$@"
  '';
  # For updates that swap glibc, systemd or PAM: a live switch leaves running
  # processes unable to load the new PAM modules, so activate on reboot.
  bootbuild = pkgs.writeShellScriptBin "bootbuild" ''
    export PATH="/run/wrappers/bin:$PATH"
    exec ${nh} os boot ${hostProfile.user.nixosConfigPath} "$@"
  '';
  # One entry point for everything flake.lock does not pin. Leaves the diff
  # uncommitted for review; packages whose download URLs carry a build ID that
  # no release feed exposes are listed for manual bumping.
  update-pins = pkgs.writeShellApplication {
    name = "update-pins";
    runtimeInputs = [
      pkgs.flatpak
      pkgs.gh
      pkgs.nix-update
    ];
    text = ''
      cd ${hostProfile.user.nixosConfigPath}
      nix flake update
      nix-update --flake magpie
      nix-update --flake wiiu-downloader
      nix-update --flake genryumin
      # Upstream's alpha tags crowd stable releases out of nix-update's feed.
      nix-update --flake codex \
        --version "$(gh release view -R openai/codex --json tagName -q '.tagName|ltrimstr("rust-v")')"
      flatpak update --user --noninteractive
      echo
      echo "Bump by hand (URL has a build ID): antigravity grok grok-bot jetbrains-maple-mono"
      git status --short
    '';
  };
  # Magpie releases several times a week and its own updater cannot write to
  # the store. Bump only Magpie, leaving flake.lock alone so no glibc-sized
  # change rides along, and commit it straight to main for the next rebuild.
  update-magpie = pkgs.writeShellApplication {
    name = "update-magpie";
    runtimeInputs = [
      pkgs.git
      pkgs.nix-update
    ];
    text = ''
      cd ${hostProfile.user.nixosConfigPath}
      if [ "$(git branch --show-current)" != main ] || ! git diff --quiet HEAD -- pkgs/magpie.nix; then
        echo "update-magpie: needs main checked out with pkgs/magpie.nix unchanged" >&2
        exit 1
      fi
      old=$(nix eval --raw .#magpie.version)
      nix-update --flake magpie
      new=$(nix eval --raw .#magpie.version)
      if [ "$old" = "$new" ]; then
        echo "magpie $old is already the latest"
        exit 0
      fi
      nix build .#magpie --no-link
      git commit -m "update magpie to $new" -- pkgs/magpie.nix
      echo "magpie $old -> $new committed; run rebuild"
    '';
  };
in

{
  home.packages = [
    rebuild
    testbuild
    bootbuild
    update-pins
    update-magpie
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

}
