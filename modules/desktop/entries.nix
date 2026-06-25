{ pkgs, lib, ... }:

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
    exec = "antigravity %F";
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
    exec = "${pkgs.nemo-with-extensions}/bin/nemo %U";
    icon = "system-file-manager";
    terminal = false;
    categories = [ "Utility" "FileTools" "System" "FileManager" ];
    mimeType = [ "inode/directory" ];
  };

  xdg.desktopEntries."qt6ct" = {
    name = "Qt6 Settings";
    exec = "qt6ct";
    icon = "preferences-desktop-theme";
    type = "Application";
    categories = [ "Settings" "DesktopSettings" "Qt" ];
    terminal = false;
    noDisplay = true;
  };
}
