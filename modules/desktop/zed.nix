{ ... }:

let
  lilyaGlass = import ../glass-settings.nix;
in

{
  xdg.desktopEntries."dev.zed.Zed" = {
    name = "Zed";
    genericName = "Text Editor";
    comment = "A high-performance, multiplayer code editor.";
    exec = "zeditor %U";
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
      exec = "zeditor --new %U";
      name = "Open a new workspace";
    };
  };

  programs.zed-editor = {
    enable = true;
    userSettings = {
      cli_default_open_behavior = "existing_window";
      proxy = "";
      agent = {
        default_model = {
          provider = "opencode";
          model = "go/kimi-k2.5";
          enable_thinking = false;
        };
        favorite_models = [];
        model_parameters = [];
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
    };
  };
}
