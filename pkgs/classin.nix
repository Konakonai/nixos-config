{ pkgs, lib, fcitxCompatEnv ? { }, ... }:

let
  pname = "classin";
  version = "6.0.8.2737";
  fcitxWrapperArgs = lib.concatStringsSep " " (
    lib.mapAttrsToList (name: value: "--set ${name} ${lib.escapeShellArg value}") fcitxCompatEnv
  );

  runtimeLibs = with pkgs; [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    e2fsprogs
    expat
    fontconfig
    freetype
    glib
    keyutils
    libGL
    libdrm
    libice
    libkrb5
    libselinux
    libsm
    libuuid
    libx11
    libxcb
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxinerama
    libxkbcommon
    libxrandr
    libxrender
    libxscrnsaver
    libxtst
    mesa
    nspr
    nss
    pango
    pcre
    pixman
    pulseaudio
    systemd
    util-linux
    xcbutilimage
    xcbutilkeysyms
    xcbutilrenderutil
    xcbutilwm
  ];
in
pkgs.stdenv.mkDerivation {
  inherit pname version;

  src = pkgs.fetchurl {
    url = "https://www.eeo.cn/download/client/classin_${version}_amd64.deb";
    hash = "sha256-w+hx6vbygQ0Mn/sW9CWaapd4T27XMPQifd3vZoLXPgc=";
  };

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  buildInputs = [ pkgs.stdenv.cc.cc.lib ] ++ runtimeLibs;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/opt/apps/classin" "$out/share"
    cp -r opt/apps/classin/. "$out/opt/apps/classin/"
    cp -r usr/share/. "$out/share/"

    rm -f "$out/opt/apps/classin/lib"/{libpixman-1.so*,libselinux.so*,libcairo.so*,libglib-2.0.so*,libgio-2.0.so*,libgobject-2.0.so*,libgmodule-2.0.so*,libgthread-2.0.so*,libdbus-1.so*,libfontconfig.so*,libfreetype.so*,libz.so*,libstdc++.so*,libgcc_s.so*,libblkid.so*,libmount.so*,libpcre.so*,libxcb*}

    substituteInPlace "$out/share/applications/classin.desktop" \
      --replace-fail 'Exec="/opt/apps/classin/ClassIn"' "Exec=classin"

    runHook postInstall
  '';

  postFixup = ''
    makeWrapper "$out/opt/apps/classin/ClassIn" "$out/bin/classin" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}:$out/opt/apps/classin/lib" \
      ${fcitxWrapperArgs} \
      --set QT_QPA_PLATFORM xcb \
      --chdir "$out/opt/apps/classin" \
      --add-flags "--no-sandbox"
  '';

  meta = {
    description = "Online interactive classroom client";
    homepage = "https://www.classin.com/";
    downloadPage = "https://www.classin.com/download/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "classin";
    platforms = [ "x86_64-linux" ];
  };
}
