{ lib, pkgs, ... }:

let
  ebookReader = "com.github.johnfactotum.Foliate.desktop";
  fontViewer = "org.gnome.font-viewer.desktop";
  imageViewer = "org.gnome.Loupe.desktop";
  mediaPlayer = "io.github.celluloid_player.Celluloid.desktop";
  pdfViewer = "okularApplication_pdf.desktop";
  presentationEditor = "impress.desktop";
  spreadsheetEditor = "calc.desktop";
  wordProcessor = "writer.desktop";

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
  xdg.desktopEntries = {
    # The system vim package ships upstream launcher entries. vim is only used
    # from a shell, and gvim.desktop points at a GUI this build does not have.
    vim = {
      name = "Vim";
      exec = "vim %F";
      terminal = true;
      noDisplay = true;
    };
    gvim = {
      name = "GVim";
      exec = "gvim -f %F";
      noDisplay = true;
    };

    nemo = {
      name = "Files";
      genericName = "File Manager";
      exec = "${pkgs.nemo-with-extensions}/bin/nemo %U";
      icon = "system-file-manager";
      terminal = false;
      categories = [
        "Utility"
        "FileTools"
        "System"
        "FileManager"
      ];
      mimeType = [ "inode/directory" ];
    };

    "org.gnome.Loupe" = {
      name = "Image Viewer";
      genericName = "Image Viewer";
      exec = "${lib.getExe pkgs.loupe} %U";
      icon = "org.gnome.Loupe";
      terminal = false;
      categories = [
        "GNOME"
        "GTK"
        "Graphics"
        "2DGraphics"
        "RasterGraphics"
        "Viewer"
      ];
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
      categories = [
        "GNOME"
        "GTK"
        "Utility"
      ];
      mimeType = fontMimeTypes;
      startupNotify = true;
      settings.DBusActivatable = "false";
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/antigravity" = "antigravity.desktop";
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
      "application/pdf" = pdfViewer;
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

      "application/ogg" = mediaPlayer;
      "application/x-flac" = mediaPlayer;
      "audio/3gpp" = mediaPlayer;
      "audio/aac" = mediaPlayer;
      "audio/flac" = mediaPlayer;
      "audio/m4a" = mediaPlayer;
      "audio/mp4" = mediaPlayer;
      "audio/mpeg" = mediaPlayer;
      "audio/ogg" = mediaPlayer;
      "audio/opus" = mediaPlayer;
      "audio/wav" = mediaPlayer;
      "audio/webm" = mediaPlayer;
      "audio/x-aac" = mediaPlayer;
      "audio/x-flac" = mediaPlayer;
      "audio/x-m4a" = mediaPlayer;
      "audio/x-matroska" = mediaPlayer;
      "audio/x-mp3" = mediaPlayer;
      "audio/x-mpeg" = mediaPlayer;
      "audio/x-ogg" = mediaPlayer;
      "audio/x-opus+ogg" = mediaPlayer;
      "audio/x-vorbis+ogg" = mediaPlayer;
      "audio/x-wav" = mediaPlayer;
      "video/mp4" = mediaPlayer;
      "video/x-matroska" = mediaPlayer;
      "video/webm" = mediaPlayer;
      "video/mpeg" = mediaPlayer;
      "video/avi" = mediaPlayer;
      "video/quicktime" = mediaPlayer;
      "video/x-flv" = mediaPlayer;
      "video/3gp" = mediaPlayer;
      "video/3gpp" = mediaPlayer;
      "video/x-ms-wmv" = mediaPlayer;
      "video/x-msvideo" = mediaPlayer;

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

      "application/vnd.ms-opentype" = fontViewer;
      "application/x-font-otf" = fontViewer;
      "application/x-font-pcf" = fontViewer;
      "application/x-font-ttf" = fontViewer;
      "application/x-font-type1" = fontViewer;
      "font/collection" = fontViewer;
      "font/otf" = fontViewer;
      "font/ttf" = fontViewer;
      "font/woff" = fontViewer;
      "font/woff2" = fontViewer;

      "application/msword" = wordProcessor;
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = wordProcessor;
      "application/vnd.openxmlformats-officedocument.wordprocessingml.template" = wordProcessor;
      "application/vnd.ms-word.document.macroEnabled.12" = wordProcessor;
      "application/vnd.ms-word.template.macroEnabled.12" = wordProcessor;
      "application/wps-office.doc" = wordProcessor;
      "application/wps-office.docx" = wordProcessor;
      "application/vnd.ms-excel" = spreadsheetEditor;
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = spreadsheetEditor;
      "application/vnd.openxmlformats-officedocument.spreadsheetml.template" = spreadsheetEditor;
      "application/vnd.ms-excel.sheet.macroEnabled.12" = spreadsheetEditor;
      "application/vnd.ms-excel.template.macroEnabled.12" = spreadsheetEditor;
      "application/vnd.ms-excel.addin.macroEnabled.12" = spreadsheetEditor;
      "application/vnd.ms-excel.sheet.binary.macroEnabled.12" = spreadsheetEditor;
      "application/wps-office.xls" = spreadsheetEditor;
      "application/wps-office.xlsx" = spreadsheetEditor;
      "application/vnd.ms-powerpoint" = presentationEditor;
      "application/vnd.openxmlformats-officedocument.presentationml.presentation" = presentationEditor;
      "application/vnd.openxmlformats-officedocument.presentationml.template" = presentationEditor;
      "application/vnd.openxmlformats-officedocument.presentationml.slideshow" = presentationEditor;
      "application/vnd.ms-powerpoint.addin.macroEnabled.12" = presentationEditor;
      "application/vnd.ms-powerpoint.presentation.macroEnabled.12" = presentationEditor;
      "application/vnd.ms-powerpoint.template.macroEnabled.12" = presentationEditor;
      "application/vnd.ms-powerpoint.slideshow.macroEnabled.12" = presentationEditor;
      "application/wps-office.ppt" = presentationEditor;
      "application/wps-office.pptx" = presentationEditor;
      "application/vnd.oasis.opendocument.text" = wordProcessor;
      "application/vnd.oasis.opendocument.spreadsheet" = spreadsheetEditor;
      "application/vnd.oasis.opendocument.presentation" = presentationEditor;
      "application/rtf" = wordProcessor;
      "text/csv" = spreadsheetEditor;
    };
  };
}
