{ pkgs, lib, ... }:

let
  pname = "qoder-cn";
  version = "1.5.0-1782824334";

  src = pkgs.fetchurl {
    url = "https://ide.qoder.com.cn/qoder/release/lastest/qoder-cn_amd64.deb";
    hash = "sha256-2VsTfzYztLlZIiHDuDVnJn3+08HVeJ8mn+GpHdjDMlw=";
  };

  runtimeLibs = with pkgs; [
    alsa-lib
    atk
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libglvnd
    libnotify
    libsecret
    libxkbcommon
    libxkbfile
    mesa
    nspr
    nss
    pango
    systemd
    vulkan-loader
    wayland
    libice
    libsm
    libx11
    libxscrnsaver
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxtst
    libxcb
    libxshmfence
  ];
in
pkgs.stdenvNoCC.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    dpkg
    gnutar
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = runtimeLibs;

  dontBuild = true;
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile "$src" | tar --no-same-owner --no-same-permissions -xf -
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share"
    cp -r usr/share/qoder-cn "$out/share/qoder-cn"

    install -Dm444 usr/share/applications/qoder-cn.desktop \
      "$out/share/applications/qoder-cn.desktop"
    install -Dm444 usr/share/applications/qoder-cn-url-handler.desktop \
      "$out/share/applications/qoder-cn-url-handler.desktop"
    install -Dm444 usr/share/appdata/qoder-cn.appdata.xml \
      "$out/share/appdata/qoder-cn.appdata.xml"
    install -Dm444 usr/share/pixmaps/QoderCN.png \
      "$out/share/pixmaps/QoderCN.png"

    substituteInPlace "$out/share/applications/qoder-cn.desktop" \
      --replace-fail "/usr/share/qoder-cn/qoder-cn" "$out/bin/qoder-cn"
    substituteInPlace "$out/share/applications/qoder-cn-url-handler.desktop" \
      --replace-fail "/usr/share/qoder-cn/qoder-cn" "$out/bin/qoder-cn"

    chmod +x "$out/share/qoder-cn/qoder-cn"
    chmod +x "$out/share/qoder-cn/chrome_crashpad_handler"
    chmod +x "$out/share/qoder-cn/resources/app/resources/bin/x86_64_linux/QoderCN"
    if [ -e "$out/share/qoder-cn/resources/app/resources/bin/x86_64_linux/qodercncli" ]; then
      chmod +x "$out/share/qoder-cn/resources/app/resources/bin/x86_64_linux/qodercncli"
    fi

    makeWrapper "$out/share/qoder-cn/qoder-cn" "$out/bin/qoder-cn" \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}" \
      --set-default ELECTRON_OZONE_PLATFORM_HINT auto \
      --set-default NIXOS_OZONE_WL 1 \
      --add-flags "--no-sandbox"

    ln -s qoder-cn "$out/bin/qoder-cn-desktop"

    runHook postInstall
  '';

  meta = {
    description = "Qoder CN Desktop - Agentic Coding Platform for Real Software";
    homepage = "https://qoder.com.cn";
    license = lib.licenses.unfree;
    mainProgram = "qoder-cn";
    platforms = [ "x86_64-linux" ];
  };
}
