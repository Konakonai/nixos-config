{ lib, pkgs, ... }:

let
  inherit (pkgs.lilya) antigravity cc-switch-cli splayer;
  localsendNoCsd = pkgs.symlinkJoin {
    name = "${pkgs.localsend.name}-no-csd";
    paths = [ pkgs.localsend ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # niri does not provide server-side decorations, and LocalSend's Flutter
    # runner otherwise adds a redundant GTK header bar on every Wayland session.
    postBuild = ''
      rm "$out/bin/localsend_app"
      makeWrapper ${lib.getExe pkgs.localsend} "$out/bin/localsend_app" \
        --set GTK_CSD 0
    '';
    meta = pkgs.localsend.meta;
  };
in
{
  home.packages = with pkgs; [
    antigravity
    file-roller
    foliate
    gnome-font-viewer
    hyprpicker
    localsendNoCsd
    loupe
    mission-center
    nemo-with-extensions
    obsidian
    pavucontrol
    pwvucontrol
    resources
    splayer
  ];

  xdg.desktopEntries = {
    "cc-switch-handler" = {
      name = "CC Switch";
      exec = "${lib.getExe cc-switch-cli} %u";
      type = "Application";
      terminal = false;
      noDisplay = true;
      mimeType = [ "x-scheme-handler/ccswitch" ];
    };

    antigravity = {
      name = "Antigravity";
      exec = "${lib.getExe antigravity} %F";
      icon = "antigravity";
      type = "Application";
      categories = [ "Utility" ];
      terminal = false;
      mimeType = [ "x-scheme-handler/antigravity" ];
    };
  };
}
