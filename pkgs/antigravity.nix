{
  lib,
  stdenv,
  pkgs,
  fetchurl,
  autoPatchelfHook,
  wrapGAppsHook3,
}:

let
  pname = "antigravity";
  version = "2.35.0";
  # The build ID in the URL comes from the release list (update-pins rewrites it):
  #   curl -fsSL https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/releases
  buildId = "6394266482769920";

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/${version}-${buildId}/linux-x64/Antigravity.tar.gz";
    hash = "sha256-uIcZy9X0CMASHud9KXQBGidIMGslkdNG60iKILxR7Ck=";
  };

  runtimeLibs = with pkgs; [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    dbus-glib
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libglvnd
    libnotify
    libpulseaudio
    libva
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxi
    libxkbcommon
    libxrandr
    libxscrnsaver
    libxshmfence
    libxtst
    mesa
    nspr
    nss
    pango
    pciutils
    pipewire
    systemd
    udev
    vulkan-loader
    wayland
  ];
in
stdenv.mkDerivation {
  inherit pname version src;

  sourceRoot = ".";
  unpackCmd = ''
    mkdir -p root
    tar -xzf "$curSrc" --strip-components=1 -C root
    sourceRoot=root
  '';

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook3
    pkgs.asar
    pkgs.nodejs
  ];

  buildInputs = runtimeLibs ++ [
    pkgs.gsettings-desktop-schemas
  ];

  runtimeDependencies = map lib.getLib runtimeLibs;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
        runHook preInstall

        # The loading overlay follows the window's 'resize' event, but on Wayland
        # Electron emits it before getContentSize() reports the size niri
        # configured, so the overlay stays at the initial 1400x900. The content
        # view's 'bounds-changed' fires after the new size is applied.
        # Checked on 2.30.0 / Electron 44.
        asar extract resources/app.asar app
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

        # Closing the last window quits the app (and drops the tray icon) unless
        # app_storage.json has runInBackground = "true"; the default is macOS-only.
        # The key went missing from our storage around 2.29, so make the default
        # keep running in the tray. An explicit toggle in Settings still wins.
        substituteInPlace app/dist/services/settingsService.js \
          --replace-fail "[SettingKey.RUN_IN_BACKGROUND, process.platform === 'darwin']" \
                         "[SettingKey.RUN_IN_BACKGROUND, true]"

    # Inject inline host-themed context meter directly into app.asar.
    install -d app/dist/context-meter
    install -m 644 ${./antigravity-context-meter}/{core,main,renderer}.js app/dist/context-meter/
    substituteInPlace app/dist/utils.js \
      --replace-fail "    void loadHubWindowUrl(win, url, { skipBootstrapMint });" \
                     $'    require("./context-meter/main").installContextMeter(win);\n    void loadHubWindowUrl(win, url, { skipBootstrapMint });' \
      --replace-fail "        wins[0].focus();" \
                     $'        wins[0].focus();\n        require("./context-meter/main").ensureMeterInjected(wins[0], { force: false });'
    node --check app/dist/context-meter/*.js app/dist/utils.js

        mkdir -p "$out/share/icons/hicolor/256x256/apps"
        cp app/icon.png "$out/share/icons/hicolor/256x256/apps/antigravity.png"

        asar pack app resources/app.asar --unpack-dir '**/chrome-devtools-mcp'
        rm -rf app

        mkdir -p "$out/opt/antigravity" "$out/bin"
        cp -r . "$out/opt/antigravity"

        # ANGLE loads this copy by absolute path; the NixOS-patched loader finds
        # ICDs under /run/opengl-driver, the bundled one does not.
        rm -f "$out/opt/antigravity/libvulkan.so.1"
        ln -s "${lib.getLib pkgs.vulkan-loader}/lib/libvulkan.so.1" "$out/opt/antigravity/libvulkan.so.1"

        ln -s "$out/opt/antigravity/antigravity" "$out/bin/antigravity"

        runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --set GTK_USE_PORTAL 1
      --set CHROME_DEVEL_SANDBOX "$out/opt/antigravity/chrome-sandbox"
    )
  '';

  meta = {
    description = "Antigravity - Agentic Desktop Application by Google";
    platforms = [ "x86_64-linux" ];
    mainProgram = "antigravity";
  };
}
