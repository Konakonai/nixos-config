{ pkgs, lib, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  hermesDesktop = inputs.hermes-agent.packages.${system}.desktop;
  hermesIcon = "${hermesDesktop}/share/hermes-desktop/dist/hermes.png";
  ccSwitch = pkgs.callPackage ../../pkgs/cc-switch-cli/default.nix {};
  antigravity = import ../../pkgs/antigravity.nix { inherit pkgs lib; };
  fontMimeTypes = [
    "application/vnd.ms-opentype"
    "application/x-font-otf"
    "application/x-font-pcf"
    "application/x-font-ttf"
    "application/x-font-type1"
    "font/collection"
    "font/otf"
    "font/ttf"
    "font/woff"
    "font/woff2"
  ];
  imageMimeTypes = [
    "image/apng"
    "image/avif"
    "image/bmp"
    "image/gif"
    "image/heic"
    "image/jpeg"
    "image/jp2"
    "image/jxl"
    "image/png"
    "image/svg+xml"
    "image/svg+xml-compressed"
    "image/tiff"
    "image/vnd.microsoft.icon"
    "image/webp"
    "image/x-dds"
    "image/x-exr"
    "image/x-portable-anymap"
    "image/x-portable-bitmap"
    "image/x-portable-graymap"
    "image/x-portable-pixmap"
    "image/x-qoi"
    "image/x-tga"
    "image/x-win-bitmap"
    "image/x-xbitmap"
    "image/x-xpixmap"
  ];
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
    exec = "${lib.getExe antigravity} %F";
    icon = "antigravity";
    type = "Application";
    categories = [ "Utility" ];
    terminal = false;
    mimeType = [ "x-scheme-handler/antigravity" ];
  };

  xdg.desktopEntries."yazi" = {
    name = "Yazi";
    genericName = "File Manager";
    exec = "${lib.getExe pkgs.kitty} -e ${lib.getExe pkgs.yazi} %u";
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
    exec = "${lib.getExe pkgs.qt6Packages.qt6ct}";
    icon = "preferences-desktop-theme";
    type = "Application";
    categories = [ "Settings" "DesktopSettings" "Qt" ];
    terminal = false;
    noDisplay = true;
  };

  xdg.desktopEntries."org.gnome.Loupe" = {
    name = "Image Viewer";
    genericName = "Image Viewer";
    exec = "${lib.getExe pkgs.loupe} %U";
    icon = "org.gnome.Loupe";
    terminal = false;
    categories = [ "GNOME" "GTK" "Graphics" "2DGraphics" "RasterGraphics" "Viewer" ];
    mimeType = imageMimeTypes;
    startupNotify = true;
    settings.DBusActivatable = "false";
  };

  xdg.desktopEntries."org.gnome.font-viewer" = {
    name = "Fonts";
    genericName = "Font Viewer";
    exec = "${lib.getExe' pkgs.gnome-font-viewer "gnome-font-viewer"} %u";
    icon = "org.gnome.font-viewer";
    terminal = false;
    categories = [ "GNOME" "GTK" "Utility" ];
    mimeType = fontMimeTypes;
    startupNotify = true;
    settings.DBusActivatable = "false";
  };

  xdg.desktopEntries."hermes-desktop" = {
    name = "Hermes";
    genericName = "AI Agent";
    exec = "${hermesDesktop}/bin/hermes-desktop";
    icon = hermesIcon;
    type = "Application";
    terminal = false;
    categories = [ "Utility" "Development" "AI" ];
    startupNotify = true;
  };
}
