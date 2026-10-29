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
  # Display 2 for claude-desktop-extra's "Computer Use on a background
  # display": Claude clicks and types there through the bundled bridge without
  # touching the user's cursor or focus. Headless, so it needs no window on the
  # real desktop; pixman, so it never wakes the dGPU (which must stay asleep on
  # battery). Pick its wayland-N socket on the setup page (Settings -> Extra ->
  # Community Features); sway takes the lowest free number, so normally wayland-2.
  cuState = ''"$XDG_RUNTIME_DIR/claude-cu"'';
  claude-cu-desk = pkgs.writeShellApplication {
    name = "claude-cu-desk";
    runtimeInputs = [ pkgs.sway ];
    text = ''
      state=${cuState}
      mkdir -p "$state"
      if [ "''${1-}" = stop ]; then
        [ -r "$state/pid" ] && kill "$(cat "$state/pid")"
        exit 0
      fi

      config="$state/sway.conf"
      {
        echo "default_border none"
        echo "focus_follows_mouse no"
        echo "output HEADLESS-1 mode 1920x1200 scale 1.25 bg #303030 solid_color"
        # shellcheck disable=SC2016
        printf '%s\n' "exec sh -c 'printf \"WAYLAND_DISPLAY=%s\\nDISPLAY=%s\\n\" \"\$WAYLAND_DISPLAY\" \"\''${DISPLAY-}\" > $state/env.tmp && mv $state/env.tmp $state/env'"
      } > "$config"

      trap 'rm -f "$state/env" "$state/pid"' EXIT
      env -u WAYLAND_DISPLAY -u DISPLAY -u NIRI_SOCKET \
        WLR_BACKENDS=headless \
        WLR_RENDERER=pixman \
        WLR_LIBINPUT_NO_DEVICES=1 \
        sway -c "$config" &
      echo $! > "$state/pid"
      wait
    '';
  };
  # Start a program on display 2 from a shell (Claude's own open_application
  # already targets it).
  claude-cu-run = pkgs.writeShellApplication {
    name = "claude-cu-run";
    text = ''
      env=${cuState}/env
      if [ ! -r "$env" ]; then
        echo "claude-cu-run: claude-cu-desk is not running" >&2
        exit 1
      fi
      set -a
      # shellcheck disable=SC1090
      . "$env"
      set +a
      exec "$@"
    '';
  };
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
    claude-cu-desk
    claude-cu-run
    claude-desktop
    file-roller
    foliate
    foot
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
