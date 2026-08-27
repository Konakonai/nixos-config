{ fcitxCompatEnv, inputs, lib, pkgs, ... }:

let
  inherit (pkgs.lilya)
    antigravity
    cc-switch
    file-roller-wayland
    localsend-no-csd
    nemo-with-extensions-wayland
    qoder
    splayer
    ;
  classin = pkgs.lilya.classin.override { inherit fcitxCompatEnv; };
  claude-desktop =
    inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop-fhs;
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
  home.packages = with pkgs; [
    antigravity
    bitwarden-desktop
    cc-switch
    claude-desktop
    classin
    file-roller-wayland
    foliate
    gnome-font-viewer
    hyprpicker
    kdePackages.okular
    localsend-no-csd
    loupe
    mcomix
    mission-center
    nemo-with-extensions-wayland
    obsidian
    pavucontrol
    pwvucontrol
    qoder
    resources
    splayer
    thunderbird
  ];

  xdg.desktopEntries = {
    antigravity = {
      name = "Antigravity";
      exec = "${lib.getExe antigravity} %F";
      icon = "antigravity";
      type = "Application";
      categories = [ "Utility" ];
      terminal = false;
      mimeType = [ "x-scheme-handler/antigravity" ];
    };

    nemo = {
      name = "Files";
      genericName = "File Manager";
      exec = "${nemo-with-extensions-wayland}/bin/nemo %U";
      icon = "system-file-manager";
      terminal = false;
      categories = [ "Utility" "FileTools" "System" "FileManager" ];
      mimeType = [ "inode/directory" ];
    };

    "org.gnome.Loupe" = {
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

    "org.gnome.font-viewer" = {
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
  };
}
