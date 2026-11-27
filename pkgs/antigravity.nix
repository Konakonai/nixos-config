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
  version = "2.35.2";
  # The build ID in the URL comes from the release list (update-pins rewrites it):
  #   curl -fsSL https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/releases
  buildId = "4585983447007232";

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/${version}-${buildId}/linux-x64/Antigravity.tar.gz";
    hash = "sha256-LTPbKCsemzx1gsFA2rnoaEjxs3oFv6Sh3/f0TeG/ME8=";
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
      # Antigravity 2.33+ requires explicit opt-in for the loopback CDP bridge
      # (127.0.0.1 ephemeral port) used by UI plugins such as Obsidian Prism.
      --add-flags "--remote-debugging-port=0"
    )
  '';

  meta = {
    description = "Antigravity - Agentic Desktop Application by Google";
    platforms = [ "x86_64-linux" ];
    mainProgram = "antigravity";
  };
}
