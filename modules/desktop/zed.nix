{ config, lib, lilyaGlass, pkgs, ... }:

let
  zed = lib.getExe config.programs.zed-editor.package;
  zedSeed = pkgs.writeText "zed-settings.json" (builtins.toJSON {
    agent_servers.codex-acp.type = "registry";
    cli_default_open_behavior = "existing_window";
    proxy = "";
    agent = {
      default_model = {
        provider = "opencode";
        model = "go/kimi-k2.5";
        enable_thinking = false;
      };
      favorite_models = [ ];
      model_parameters = [ ];
    };
    session.trust_all_worktrees = true;
    ui_font_family = lilyaGlass.fonts.mono;
    buffer_font_family = lilyaGlass.fonts.mono;
    ui_font_size = 16;
    buffer_font_size = 15;
    theme = {
      mode = "light";
      light = "Noctalia Light";
      dark = "Noctalia Dark";
    };
  });
in

{
  xdg.desktopEntries."dev.zed.Zed" = {
    name = "Zed";
    genericName = "Text Editor";
    comment = "A high-performance, multiplayer code editor.";
    exec = "${zed} %U";
    icon = "zed";
    type = "Application";
    categories = [ "Utility" "TextEditor" "Development" "IDE" ];
    mimeType = [
      "text/plain"
      "application/x-zerosize"
      "x-scheme-handler/zed"
      "text/markdown"
      "application/json"
      "application/x-toml"
      "application/x-yaml"
      "text/x-python"
      "text/x-shellscript"
    ];
    settings.StartupNotify = "true";
    actions.NewWorkspace = {
      exec = "${zed} --new %U";
      name = "Open a new workspace";
    };
  };

  programs.zed-editor.enable = true;

  xdg.dataFile."nixos-config/defaults/zed-settings.json".source = zedSeed;

  home.activation.seedZedSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings_file=${lib.escapeShellArg "${config.xdg.configHome}/zed/settings.json"}

    if [ -L "$settings_file" ]; then
      target="$(${pkgs.coreutils}/bin/readlink -f "$settings_file" || true)"
      case "$target" in
        /nix/store/*) ${pkgs.coreutils}/bin/rm -f "$settings_file" ;;
      esac
    fi

    if [ ! -e "$settings_file" ]; then
      ${pkgs.coreutils}/bin/install -Dm600 ${zedSeed} "$settings_file"
    fi
  '';
}
