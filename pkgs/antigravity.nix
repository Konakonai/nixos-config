{ pkgs, lib, ... }:

let
  src = pkgs.fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.11.0-6376446768316416/linux-x64/Antigravity.tar.gz";
    hash = "sha256-Q7HiV/0mFN25paV4sD+Kw5H2V5s7Big6vhWWQVf2USk=";
  };

  antigravity-src = pkgs.runCommand "antigravity-src" {
    nativeBuildInputs = [ pkgs.gnutar pkgs.gzip pkgs.asar ];
    inherit src;
  } ''
    mkdir -p "$out"
    tar -xzf "$src" --strip-components=1 -C "$out"

    # Antigravity's loading overlay can size itself too early on this Wayland
    # setup; trigger a few delayed bounds refreshes after window changes.
    asar extract "$out/resources/app.asar" app
    substituteInPlace app/dist/loadingOverlay.js \
      --replace-fail "    updateBounds();" "    updateBounds();
    setTimeout(updateBounds, 0);
    setTimeout(updateBounds, 100);
    setTimeout(updateBounds, 500);" \
      --replace-fail "    win.on('resize', updateBounds);" "    win.on('resize', updateBounds);
    win.on('resized', updateBounds);
    win.on('show', updateBounds);" \
      --replace-fail "        win.off('resize', updateBounds);" "        win.off('resize', updateBounds);
        win.off('resized', updateBounds);
        win.off('show', updateBounds);"

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
    targetPkgs = p: with p; [
      glib glib.bin gtk3 pango cairo atk at-spi2-atk at-spi2-core
      gdk-pixbuf shared-mime-info gsettings-desktop-schemas
      cups
      nspr nss
      dbus dbus-glib
      expat
      alsa-lib
      libxkbcommon
      wayland
      mesa libgbm libdrm
      libx11 libxcomposite libxdamage libxext
      libxfixes libxrandr libxcb libxshmfence
      libxtst libxscrnsaver libxi
      pipewire libpulseaudio
      systemd libnotify
      libglvnd vulkan-loader
    ];
    runScript = "${launcher}";
  };

  icon = pkgs.runCommand "antigravity-icon" {
    buildInputs = [ pkgs.asar ];
  } ''
    asar extract ${antigravity-src}/resources/app.asar app
    mkdir -p $out/share/icons/hicolor/256x256/apps
    cp app/icon.png $out/share/icons/hicolor/256x256/apps/antigravity.png
  '';
in
pkgs.symlinkJoin {
  name = "antigravity";
  paths = [ fhs-env icon ];
  meta = {
    description = "Antigravity - Agentic Desktop Application by Google";
    platforms = [ "x86_64-linux" ];
    mainProgram = "antigravity";
  };
}
