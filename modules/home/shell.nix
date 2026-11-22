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
  # uncommitted for review; packages with no feed to ask are listed for manual
  # bumping.
  update-pins = pkgs.writeShellApplication {
    name = "update-pins";
    runtimeInputs = [
      pkgs.curl
      pkgs.flatpak
      pkgs.gnused
      pkgs.jq
      pkgs.lilya.nix-update
    ];
    text = ''
      cd ${hostProfile.user.nixosConfigPath}
      nix flake update
      nix-update --flake wiiu-downloader
      nix-update --flake genryumin
      nix-update --flake gemini-api
      nix-update --flake google-colab-cli
      nix-update --flake opencli
      # Antigravity embeds a build ID in the URL, which nix-update cannot
      # derive from the version: rewrite it first, then let nix-update set
      # the version and refetch the hash.
      bump_with_id() { # <attr> <id binding> <version> <id>
        # Empty when the endpoint changed shape; command substitutions in
        # arguments do not trip errexit, so check here.
        if [ -z "$3" ] || [ -z "$4" ]; then
          echo "$1: unexpected updater response" >&2
          return 1
        fi
        if [ "$3" = "$(nix eval --raw ".#$1.version")" ]; then
          echo "$1: $3 is current"
          return
        fi
        sed -i -E "s|^(  $2 = \")[^\"]*\"|\1$4\"|" "pkgs/$1.nix"
        nix-update --flake "$1" --version "$3"
      }
      release=$(curl -fsSL --connect-timeout 10 --max-time 30 https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/releases |
        jq -e 'max_by(.version | split(".") | map(tonumber))')
      bump_with_id antigravity buildId \
        "$(jq -er .version <<<"$release")" "$(jq -er .execution_id <<<"$release")"
      flatpak update --user --noninteractive
      echo
      echo "Bump by hand: jetbrains-maple-mono"
      git status --short
    '';
  };
in

{
  home.packages = [
    rebuild
    testbuild
    bootbuild
    update-pins
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
