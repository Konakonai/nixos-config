{ pkgs, lib, ... }:

let
  pname = "brave-origin";
  version = "1.92.138";

  src = pkgs.fetchurl {
    url = "https://github.com/brave/brave-browser/releases/download/v${version}/brave-origin_${version}_amd64.deb";
    hash = "sha256-38DTkrV6tQZ3vej23R8fXYZmWHbPVuqbO95g6vcsp44=";
  };

  runtimeLibs = with pkgs; [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    gtk4
    libdrm
    libgbm
    libglvnd
    libkrb5
    libuuid
    libva
    libxkbcommon
    nspr
    nss
    pango
    pipewire
    qt6.qtbase
    snappy
    systemd
    udev
    wayland
    zlib
    libpulseaudio
    libxcb
    libx11
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxscrnsaver
    libxshmfence
    libxtst
  ];

  rpath = lib.makeLibraryPath runtimeLibs + ":" + lib.makeSearchPathOutput "lib" "lib64" runtimeLibs;
  binpath = lib.makeBinPath runtimeLibs;
in
pkgs.stdenv.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = with pkgs; [
    dpkg
    (buildPackages.wrapGAppsHook3.override { makeWrapper = buildPackages.makeShellWrapper; })
  ];

  buildInputs = with pkgs; [
    adwaita-icon-theme
    glib
    gsettings-desktop-schemas
    gtk3
    gtk4
  ];

  dontConfigure = true;
  dontBuild = true;
  dontPatchELF = true;
  doInstallCheck = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile "$src" | tar --no-same-owner --no-same-permissions -xf -
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    cp -R usr/share "$out"
    cp -R opt "$out/opt"

    binaryWrapper="$out/opt/brave.com/brave-origin/brave-origin"

    substituteInPlace "$binaryWrapper" \
      --replace-fail /bin/bash ${pkgs.stdenv.shell} \
      --replace-fail 'CHROME_WRAPPER' 'WRAPPER'

    ln -sf "$binaryWrapper" "$out/bin/brave-origin"
    ln -sf "$binaryWrapper" "$out/bin/brave-origin-stable"

    for exe in "$out/opt/brave.com/brave-origin/brave" "$out/opt/brave.com/brave-origin/chrome_crashpad_handler"; do
      patchelf \
        --set-interpreter "$(cat "$NIX_CC/nix-support/dynamic-linker")" \
        --set-rpath "${rpath}" \
        "$exe"
    done

    substituteInPlace "$out"/share/applications/{brave-origin,com.brave.Origin}.desktop \
      --replace-fail /usr/bin/brave-origin-stable "$out/bin/brave-origin"
    substituteInPlace "$out/share/gnome-control-center/default-apps/brave-origin.xml" \
      --replace-fail /opt/brave.com "$out/opt/brave.com"
    substituteInPlace "$out/opt/brave.com/brave-origin/default-app-block" \
      --replace-fail /opt/brave.com "$out/opt/brave.com"

    ln -s ${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm \
      "$out/opt/brave.com/brave-origin/WidevineCdm"

    for icon in 16 24 32 48 64 128 256; do
      mkdir -p "$out/share/icons/hicolor/''${icon}x''${icon}/apps"
      ln -s "$out/opt/brave.com/brave-origin/product_logo_''${icon}.png" \
        "$out/share/icons/hicolor/''${icon}x''${icon}/apps/brave-origin.png"
    done

    ln -sf ${pkgs.xdg-utils}/bin/xdg-settings "$out/opt/brave.com/brave-origin/xdg-settings"
    ln -sf ${pkgs.xdg-utils}/bin/xdg-mime "$out/opt/brave.com/brave-origin/xdg-mime"

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "${rpath}"
      --prefix PATH : "${binpath}"
      --suffix PATH : "${lib.makeBinPath [ pkgs.xdg-utils pkgs.coreutils ]}"
      --set CHROME_WRAPPER ${pname}
      --add-flags "--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder''${NIXOS_OZONE_WL:+''${WAYLAND_DISPLAY:+,WaylandWindowDecorations --enable-wayland-ime=true}}"
      --add-flags "--disable-features=OutdatedBuildDetector,UseChromeOSDirectVideoDecoder"
      --add-flags "''${NIXOS_OZONE_WL:+''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"
    )
  '';

  installCheckPhase = ''
    "$out/opt/brave.com/brave-origin/brave" --version
    test -e "$out/opt/brave.com/brave-origin/WidevineCdm/manifest.json"
    test -e "$out/opt/brave.com/brave-origin/WidevineCdm/_platform_specific/linux_x64/libwidevinecdm.so"
  '';

  meta = {
    description = "Brave Origin minimalist browser";
    homepage = "https://brave.com/origin/";
    changelog = "https://github.com/brave/brave-browser/releases/tag/v${version}";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = [
      lib.licenses.mpl20
      lib.licenses.unfree
    ];
    mainProgram = "brave-origin";
    platforms = [ "x86_64-linux" ];
  };
}
