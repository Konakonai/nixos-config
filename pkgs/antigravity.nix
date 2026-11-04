{ pkgs, ... }:

let
  # The build ID in the URL comes from the release list:
  #   curl -fsSL https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/releases
  src = pkgs.fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.29.0-5723181030440960/linux-x64/Antigravity.tar.gz";
    hash = "sha256-OmdXBLmzowcOBsDVDTUzBDr1RSHNFcZUlOnNwr8YlmQ=";
  };

  antigravity-src =
    pkgs.runCommand "antigravity-src"
      {
        nativeBuildInputs = [
          pkgs.gnutar
          pkgs.gzip
          pkgs.asar
        ];
        inherit src;
      }
      ''
        mkdir -p "$out"
        tar -xzf "$src" --strip-components=1 -C "$out"

        # The loading overlay follows the window's 'resize' event, but on Wayland
        # Electron emits it before getContentSize() reports the size niri
        # configured, so the overlay stays at the initial 1400x900. The content
        # view's 'bounds-changed' fires after the new size is applied.
        # Checked on 2.29.0 / Electron 44.
        asar extract "$out/resources/app.asar" app
        substituteInPlace app/dist/loadingOverlay.js \
          --replace-fail "const [width, height] = win.getContentSize();" \
                         "const { width, height } = win.contentView.getBounds();" \
          --replace-fail "win.on('resize', updateBounds);" \
                         "win.contentView.on('bounds-changed', updateBounds);" \
          --replace-fail "win.off?.('resize', updateBounds);" \
                         "win.contentView.off('bounds-changed', updateBounds);"

        # Antigravity already provides a draggable app title bar. Disable
        # Electron's native overlay so it does not add a mismatched control block.
        substituteInPlace app/dist/utils.js \
          --replace-fail "titleBarOverlay: isMacOS()" "titleBarOverlay: true"

        asar pack app "$out/resources/app.asar"
      '';

  launcher = pkgs.writeShellScript "antigravity-launcher" ''
    export GTK_USE_PORTAL=1
    exec ${antigravity-src}/antigravity "$@"
  '';

  fhs-env = pkgs.buildFHSEnv {
    name = "antigravity";
    targetPkgs =
      p: with p; [
        glib
        glib.bin
        gtk3
        pango
        cairo
        atk
        at-spi2-atk
        at-spi2-core
        gdk-pixbuf
        shared-mime-info
        gsettings-desktop-schemas
        cups
        nspr
        nss
        dbus
        dbus-glib
        expat
        alsa-lib
        libxkbcommon
        wayland
        mesa
        libgbm
        libdrm
        libx11
        libxcomposite
        libxdamage
        libxext
        libxfixes
        libxrandr
        libxcb
        libxshmfence
        libxtst
        libxscrnsaver
        libxi
        pipewire
        libpulseaudio
        systemd
        libnotify
        libglvnd
        vulkan-loader
      ];
    runScript = "${launcher}";
  };

  icon =
    pkgs.runCommand "antigravity-icon"
      {
        buildInputs = [ pkgs.asar ];
      }
      ''
        asar extract ${antigravity-src}/resources/app.asar app
        mkdir -p $out/share/icons/hicolor/256x256/apps
        cp app/icon.png $out/share/icons/hicolor/256x256/apps/antigravity.png
      '';
in
pkgs.symlinkJoin {
  name = "antigravity";
  paths = [
    fhs-env
    icon
  ];
  meta = {
    description = "Antigravity - Agentic Desktop Application by Google";
    platforms = [ "x86_64-linux" ];
    mainProgram = "antigravity";
  };
}
