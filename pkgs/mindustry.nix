{ pkgs, lib, ... }:

let
  pname = "mindustry";
  version = "159.2";
  src = pkgs.requireFile {
    name = "mindustry-linux-64-bit.zip";
    hash = "sha256-wG0p6S//iXxaBDGBmwp5u+weCigDHsee6rSMYohmpno=";
    message = ''
      Download the Mindustry ${version} Linux archive and add it to the Nix store:
        nix-store --add-fixed sha256 /home/lilya/Downloads/mindustry-linux-64-bit.zip
    '';
  };

  runtimeLibs = with pkgs; [
    alsa-lib
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
    libdrm
    libglvnd
    libpulseaudio
    libX11
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXinerama
    libXrandr
    libXrender
    libXtst
    libxcb
    libxkbcommon
    mesa
    nspr
    nss
    openal
    pango
    pipewire
    wayland
  ];
in
pkgs.stdenvNoCC.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    makeWrapper
    unzip
  ];

  buildInputs = runtimeLibs;

  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    unzip "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    install -d "$out/lib/mindustry"
    cp -R ./. "$out/lib/mindustry/"
    rm -f "$out/lib/mindustry/env-vars"

    install -d "$out/bin"
    makeWrapper "$out/lib/mindustry/Mindustry" "$out/bin/mindustry" \
      --chdir "$out/lib/mindustry" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}"

    install -Dm644 /dev/null "$out/share/icons/hicolor/64x64/apps/mindustry.png"
    unzip -p "$out/lib/mindustry/jre/desktop.jar" icons/icon_64.png \
      > "$out/share/icons/hicolor/64x64/apps/mindustry.png"

    runHook postInstall
  '';

  meta = {
    description = "Sandbox tower defense game";
    homepage = "https://mindustrygame.github.io/";
    license = lib.licenses.gpl3Only;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
