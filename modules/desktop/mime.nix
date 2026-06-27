{ ... }:

let
  ebookReader = "com.github.johnfactotum.Foliate.desktop";
  imageViewer = "org.gnome.Loupe.desktop";
in
{
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/antigravity" = "antigravity.desktop";
      "x-scheme-handler/ccswitch" = "cc-switch-handler.desktop";
      "x-scheme-handler/http" = "zen-beta.desktop";
      "x-scheme-handler/https" = "zen-beta.desktop";
      "x-scheme-handler/chrome" = "zen-beta.desktop";
      "text/html" = "zen-beta.desktop";
      "application/x-extension-htm" = "zen-beta.desktop";
      "application/x-extension-html" = "zen-beta.desktop";
      "application/x-extension-shtml" = "zen-beta.desktop";
      "application/xhtml+xml" = "zen-beta.desktop";
      "application/x-extension-xhtml" = "zen-beta.desktop";
      "application/x-extension-xht" = "zen-beta.desktop";
      "application/pdf" = "zen-beta.desktop";
      "inode/directory" = "nemo.desktop";
      "x-scheme-handler/opds" = ebookReader;

      "image/apng" = imageViewer;
      "image/avif" = imageViewer;
      "image/bmp" = imageViewer;
      "image/gif" = imageViewer;
      "image/heic" = imageViewer;
      "image/jpeg" = imageViewer;
      "image/jp2" = imageViewer;
      "image/jxl" = imageViewer;
      "image/png" = imageViewer;
      "image/svg+xml" = imageViewer;
      "image/svg+xml-compressed" = imageViewer;
      "image/tiff" = imageViewer;
      "image/vnd.microsoft.icon" = imageViewer;
      "image/webp" = imageViewer;
      "image/x-portable-anymap" = imageViewer;
      "image/x-portable-bitmap" = imageViewer;
      "image/x-portable-graymap" = imageViewer;
      "image/x-portable-pixmap" = imageViewer;
      "image/x-tga" = imageViewer;
      "image/x-win-bitmap" = imageViewer;
      "image/x-xbitmap" = imageViewer;
      "image/x-xpixmap" = imageViewer;

      "video/mp4" = "io.github.celluloid_player.Celluloid.desktop";
      "video/x-matroska" = "io.github.celluloid_player.Celluloid.desktop";
      "video/webm" = "io.github.celluloid_player.Celluloid.desktop";
      "video/mpeg" = "io.github.celluloid_player.Celluloid.desktop";
      "video/avi" = "io.github.celluloid_player.Celluloid.desktop";
      "video/quicktime" = "io.github.celluloid_player.Celluloid.desktop";
      "video/x-flv" = "io.github.celluloid_player.Celluloid.desktop";
      "video/3gp" = "io.github.celluloid_player.Celluloid.desktop";
      "video/3gpp" = "io.github.celluloid_player.Celluloid.desktop";
      "video/x-ms-wmv" = "io.github.celluloid_player.Celluloid.desktop";
      "video/x-msvideo" = "io.github.celluloid_player.Celluloid.desktop";

      "application/zip" = "org.gnome.FileRoller.desktop";
      "application/x-tar" = "org.gnome.FileRoller.desktop";
      "application/x-gzip" = "org.gnome.FileRoller.desktop";
      "application/x-bzip2" = "org.gnome.FileRoller.desktop";
      "application/x-7z-compressed" = "org.gnome.FileRoller.desktop";
      "application/x-rar" = "org.gnome.FileRoller.desktop";
      "application/x-xz" = "org.gnome.FileRoller.desktop";

      "text/plain" = "dev.zed.Zed.desktop";
      "text/markdown" = "dev.zed.Zed.desktop";
      "application/json" = "dev.zed.Zed.desktop";
      "application/x-yaml" = "dev.zed.Zed.desktop";
      "application/x-toml" = "dev.zed.Zed.desktop";
      "text/x-python" = "dev.zed.Zed.desktop";
      "text/x-shellscript" = "dev.zed.Zed.desktop";

      "application/epub+zip" = ebookReader;
      "application/vnd.amazon.mobi8-ebook" = ebookReader;
      "application/vnd.comicbook+zip" = ebookReader;
      "application/x-fictionbook+xml" = ebookReader;
      "application/x-mobipocket-ebook" = ebookReader;
      "application/x-zip-compressed-fb2" = ebookReader;

      "application/msword" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.openxmlformats-officedocument.wordprocessingml.template" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-word.document.macroEnabled.12" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-word.template.macroEnabled.12" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-excel" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.openxmlformats-officedocument.spreadsheetml.template" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-excel.sheet.macroEnabled.12" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-excel.template.macroEnabled.12" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-excel.addin.macroEnabled.12" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-excel.sheet.binary.macroEnabled.12" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-powerpoint" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.openxmlformats-officedocument.presentationml.presentation" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.openxmlformats-officedocument.presentationml.template" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.openxmlformats-officedocument.presentationml.slideshow" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-powerpoint.addin.macroEnabled.12" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-powerpoint.presentation.macroEnabled.12" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-powerpoint.template.macroEnabled.12" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-powerpoint.slideshow.macroEnabled.12" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.oasis.opendocument.text" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.oasis.opendocument.spreadsheet" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.oasis.opendocument.presentation" = "org.onlyoffice.desktopeditors.desktop";
      "application/rtf" = "org.onlyoffice.desktopeditors.desktop";
      "text/csv" = "org.onlyoffice.desktopeditors.desktop";
    };
  };
}
