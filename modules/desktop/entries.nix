{ pkgs, lib, withFcitx, ... }:

let
  ccSwitch = pkgs.callPackage ../../pkgs/cc-switch-cli/default.nix {};
in
{
  xdg.desktopEntries."cc-switch-handler" = {
    name = "CC Switch";
    exec = "${lib.getExe ccSwitch} %u";
    type = "Application";
    terminal = false;
    noDisplay = true;
    mimeType = [ "x-scheme-handler/ccswitch" ];
  };

  xdg.desktopEntries."antigravity" = {
    name = "Antigravity";
    exec = withFcitx "antigravity %F";
    icon = "antigravity";
    type = "Application";
    categories = [ "Utility" ];
    terminal = false;
    mimeType = [ "x-scheme-handler/antigravity" ];
  };

  xdg.desktopEntries."yazi" = {
    name = "Yazi";
    genericName = "File Manager";
    exec = "kitty -e yazi %u";
    icon = "yazi";
    terminal = false;
    categories = [ "Utility" "FileTools" "System" "FileManager" ];
    mimeType = [ "inode/directory" ];
  };

  xdg.desktopEntries."nemo" = {
    name = "Files";
    genericName = "File Manager";
    exec = withFcitx "${pkgs.nemo-with-extensions}/bin/nemo %U";
    icon = "system-file-manager";
    terminal = false;
    categories = [ "Utility" "FileTools" "System" "FileManager" ];
    mimeType = [ "inode/directory" ];
  };

  xdg.desktopEntries."toggle-power-mode" = {
    name = "切换省电/插电模式";
    genericName = "电源模式切换";
    comment = "在一键省电模式与满血插电模式之间进行切换";
    exec = "toggle-power-mode";
    icon = "battery";
    type = "Application";
    categories = [ "Utility" "System" ];
    terminal = false;
    noDisplay = true;
  };
}
