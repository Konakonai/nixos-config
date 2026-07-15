{ config, lib, pkgs, ... }:

let
  zed = lib.getExe config.programs.zed-editor.package;
in

{
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    enableBashIntegration = true;

    theme.flavor = {
      dark = "noctalia";
      light = "noctalia";
    };

    plugins = with pkgs.yaziPlugins; {
      "full-border" = {
        package = full-border;
        setup = true;
      };
      git = {
        package = git;
        setup = true;
        settings.order = 1500;
      };
      "recycle-bin" = {
        package = recycle-bin;
        setup = true;
      };
      "smart-enter" = smart-enter;
      "smart-paste" = smart-paste;
      "toggle-pane" = toggle-pane;
      "jump-to-char" = jump-to-char;
      chmod = chmod;
      compress = compress;
      sudo = sudo;
      mount = mount;
      "wl-clipboard" = wl-clipboard;
      drag = drag;
    };

    keymap.mgr.prepend_keymap = [
      { on = "<C-n>"; run = "plugin drag"; desc = "Drag selected files with ripdrag"; }
      { on = "l"; run = "plugin smart-enter"; desc = "Enter directory or open file"; }
      { on = "p"; run = "plugin smart-paste"; desc = "Paste into hovered directory or CWD"; }
      { on = "f"; run = "plugin jump-to-char"; desc = "Jump to file by first character"; }
      { on = "T"; run = "plugin toggle-pane min-preview"; desc = "Show or hide preview pane"; }
      { on = [ "c" "m" ]; run = "plugin chmod"; desc = "Chmod selected files"; }
      { on = [ "c" "a" "a" ]; run = "plugin compress"; desc = "Archive selected files"; }
      { on = [ "c" "a" "p" ]; run = "plugin compress -p"; desc = "Archive selected files with password"; }
      { on = [ "c" "a" "l" ]; run = "plugin compress -l"; desc = "Archive selected files with compression level"; }
      { on = "M"; run = "plugin mount"; desc = "Open mount manager"; }
      { on = [ "R" "b" ]; run = "plugin recycle-bin"; desc = "Open recycle bin menu"; }
      { on = "<C-y>"; run = "plugin wl-clipboard"; desc = "Copy selected files to Wayland clipboard"; }
      { on = [ "S" "p" ]; run = "plugin sudo -- paste"; desc = "Sudo paste"; }
      { on = [ "S" "r" ]; run = "plugin sudo -- rename"; desc = "Sudo rename"; }
      { on = [ "S" "a" ]; run = "plugin sudo -- create"; desc = "Sudo create"; }
      { on = [ "S" "d" ]; run = "plugin sudo -- remove"; desc = "Sudo trash"; }
      { on = [ "S" "D" ]; run = "plugin sudo -- remove --permanently"; desc = "Sudo delete permanently"; }
      { on = [ "S" "m" ]; run = "plugin sudo -- chmod"; desc = "Sudo chmod"; }
    ];

    settings = {
      opener = {
        edit = [
          { run = ''$EDITOR "$@"''; block = true; desc = "System Editor ($EDITOR)"; }
        ];
        zed = [
          { run = ''${zed} "$@"''; orphan = true; desc = "Zed Editor"; }
        ];
        zen = [
          { run = ''zen-beta "$@"''; orphan = true; desc = "Zen Browser"; }
        ];
        system = [
          { run = ''xdg-open "$@"''; orphan = true; desc = "System Default (xdg-open)"; }
        ];
        archive = [
          { run = ''file-roller "$@"''; orphan = true; desc = "File Roller (Archive Manager)"; }
        ];
      };

      open.rules = [
        { url = "*.md"; use = [ "zed" "edit" "system" ]; }
        { url = "*.txt"; use = [ "zed" "edit" "system" ]; }
        { url = "*.json"; use = [ "zed" "edit" "system" ]; }
        { url = "*.toml"; use = [ "zed" "edit" "system" ]; }
        { url = "*.yaml"; use = [ "zed" "edit" "system" ]; }
        { url = "*.yml"; use = [ "zed" "edit" "system" ]; }
        { url = "*.py"; use = [ "zed" "edit" "system" ]; }
        { url = "*.sh"; use = [ "zed" "edit" "system" ]; }
        { url = "*.html"; use = [ "zen" "system" ]; }
        { url = "*.pdf"; use = [ "zen" "system" ]; }
        { url = "*.zip"; use = [ "archive" "system" ]; }
        { url = "*.7z"; use = [ "archive" "system" ]; }
        { url = "*.rar"; use = [ "archive" "system" ]; }
        { url = "*.tar.gz"; use = [ "archive" "system" ]; }
        { url = "*.tar.xz"; use = [ "archive" "system" ]; }
        { url = "*"; use = [ "system" "edit" ]; }
      ];

      plugin.prepend_fetchers = [
        {
          id = "git";
          url = "*";
          run = "git";
          group = "git";
        }
        {
          id = "git";
          url = "*/";
          run = "git";
          group = "git";
        }
      ];
    };
  };

  xdg.configFile."yazi/theme.toml".force = true;

  xdg.desktopEntries.yazi = {
    name = "Yazi";
    genericName = "File Manager";
    exec = "${pkgs.lib.getExe pkgs.kitty} -e ${pkgs.lib.getExe pkgs.yazi} %u";
    icon = "yazi";
    terminal = false;
    categories = [ "Utility" "FileTools" "System" "FileManager" ];
    mimeType = [ "inode/directory" ];
  };
}
