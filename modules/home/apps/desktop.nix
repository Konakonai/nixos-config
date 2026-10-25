{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs.lilya)
    agy
    antigravity
    grok-bot
    localsend-no-csd
    magpie
    ;
  claude-desktop =
    (inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop.override {
      # Upstream v2.2553.x is built against Electron 44; nixpkgs' default
      # `electron` alias lags behind, so pin the major the bundle expects.
      electron = pkgs.electron_44;
    }).overrideAttrs
      (oldAttrs: {
        postFixup = (oldAttrs.postFixup or "") + ''
          wrapProgram $out/bin/claude-desktop \
            --set CHROME_DEVEL_SANDBOX "$out/lib/claude-desktop/chrome-sandbox"

          # The bundled node-pty binding links libstdc++, but Electron itself
          # ships a static libc++, so nothing in the process provides it and
          # the pty-host worker dies with a misleading "Cannot find module
          # pty.node" (the built-in terminal shows "Failed to spawn shell").
          # Give the binding its own RPATH instead of leaking LD_LIBRARY_PATH
          # into every shell and MCP server the app spawns.
          pty=$out/lib/claude-desktop/resources/app.asar.unpacked/node_modules/node-pty/prebuilds/linux-x64/pty.node
          chmod u+w "$pty"
          patchelf --add-rpath ${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]} "$pty"
        '';
      });
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
    agy
    antigravity
    claude-desktop
    file-roller
    foliate
    gimp
    gnome-font-viewer
    grok-bot
    hyprpicker
    jellyfin-desktop
    kdePackages.okular
    localsend-no-csd
    loupe
    magpie
    mcomix
    nemo-with-extensions
    obsidian
    pavucontrol
    resources
    splayer-next
    thunderbird
  ];

  # Magpie registers its unwrapped store executable in a user desktop file,
  # which shadows the packaged launcher and stays on an old version after updates.
  # Manage the user entry too, so Magpie cannot replace the wrapped launcher.
  xdg.dataFile."applications/magpie.desktop" = {
    source = "${magpie}/share/applications/magpie.desktop";
    force = true;
  };

  # Magpie's "launch at login" writes the same kind of pinned path into its
  # autostart entry, so every login brought back the tray of whatever version
  # was installed when the toggle was flipped, and later launches only focused
  # that instance. Own the entry and point it at the wrapped launcher. If Home
  # Manager ever moves a replaced entry aside, delete the .backup copy:
  # systemd's xdg-autostart generator still starts it.
  xdg.configFile."autostart/magpie.desktop" = {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Magpie
      Exec=${lib.getExe magpie} tray
      Icon=magpie
      Terminal=false
      X-GNOME-Autostart-enabled=true
    '';
    force = true;
  };

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
}
