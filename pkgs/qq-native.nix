{ pkgs, lib, ... }:

let
  pname = "qq-native";
  version = "3.2.29-2026-05-28";

  src = pkgs.fetchurl {
    url = "https://qqdl.gtimg.cn/qqfile/QQNT/9.9.31/release/00e6a3e7/QQ_3.2.29_260528_amd64_01.deb";
    hash = "sha256-HjgoB5ZzyUmUvA9HgNXYUoZHY5kgZZhi1J0cLyoZjiU=";
  };

  runtimeLibs = with pkgs; [
    libGL
    libuuid
  ];

  buildInputs = with pkgs; [
    alsa-lib
    at-spi2-core
    cups
    glib
    gtk3
    libdrm
    libpulseaudio
    libgcrypt
    libkrb5
    libgbm
    nss
    vips
    libxdamage
  ];

  versionConfigScript = pkgs.writeShellScript "qq-native-version-config.sh" ''
    set -e

    if [[ -z "$INTERNAL_VERSION" ]]; then
      exit 0
    fi

    CONFIG_PATH="$HOME/.config/QQ/versions/config.json"
    CONFIG_DIR="$(dirname "$CONFIG_PATH")"
    mkdir -p "$CONFIG_DIR"

    if [[ -f "$CONFIG_PATH" && ! -w "$CONFIG_PATH" ]]; then
      chmod u+w "$CONFIG_PATH"
    fi

    cat > "$CONFIG_PATH" << EOF
    {
      "_comment": "This file is managed by qq-native to disable auto updates.",
      "baseVersion": "$INTERNAL_VERSION",
      "curVersion": "$INTERNAL_VERSION",
      "buildId": "''${INTERNAL_VERSION##*-}"
    }
    EOF

    chmod u-w "$CONFIG_PATH"
  '';
in
pkgs.stdenv.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    dpkg
    makeShellWrapper
    wrapGAppsHook3
  ];

  inherit buildInputs;

  dontWrapGApps = true;

  runtimeDependencies = map lib.getLib [
    pkgs.systemd
    pkgs.libkrb5
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile "$src" | tar --no-same-owner --no-same-permissions -xf -
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp -r opt $out/opt
    cp -r usr/share $out/share

    substituteInPlace $out/share/applications/qq.desktop \
      --replace-fail "/opt/QQ/qq" "$out/bin/qq-native" \
      --replace-fail "/usr/share" "$out/share" \
      --replace "Name=QQ" "Name=QQ Native Test"

    makeShellWrapper $out/opt/QQ/qq $out/bin/qq-native \
      --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH" \
      --prefix LD_PRELOAD : "${pkgs.libssh2}/lib/libssh2.so.1" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}" \
      --set-default NIXOS_OZONE_WL 1 \
      --add-flags "''${NIXOS_OZONE_WL:+''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true --wayland-text-input-version=3}}" \
      --set INTERNAL_VERSION "$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' $out/opt/QQ/resources/app/package.json)" \
      --run '${versionConfigScript} || true' \
      "''${gappsWrapperArgs[@]}"

    rm -r $out/opt/QQ/resources/app/sharp-lib
    rm -r $out/opt/QQ/resources/app/libssh2.so.1

    ln -s ${pkgs.libayatana-appindicator}/lib/libayatana-appindicator3.so \
      $out/opt/QQ/libappindicator3.so
    ln -s ${pkgs.libnotify}/lib/libnotify.so \
      $out/opt/QQ/libnotify.so

    runHook postInstall
  '';

  meta = {
    description = "Native QQ test package";
    homepage = "https://im.qq.com/linuxqq/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "qq-native";
    platforms = [ "x86_64-linux" ];
  };
}
