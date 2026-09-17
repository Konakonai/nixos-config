{ pkgs, lib, ... }:

let
  pname = "wiiu-downloader";
  version = "2.98";
  src = pkgs.fetchurl {
    url = "https://github.com/Xpl0itU/WiiUDownloader/releases/download/v${version}/WiiUDownloader-Linux-x86_64.AppImage";
    hash = "sha256-9NDrEHMxweTleLcTakfceJEZvwGCzcxfIr2DOkmrAKg=";
  };
  icon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Xpl0itU/WiiUDownloader/v${version}/data/WiiUDownloader.svg";
    hash = "sha256-Czed+uAS3kMIE8zIUogIl8/VqPVo5tL0bqBUcte806o=";
  };
  desktopItem = pkgs.makeDesktopItem {
    name = pname;
    desktopName = "WiiUDownloader";
    genericName = "Wii U title downloader";
    comment = "Browse and download Wii U titles from Nintendo's servers";
    exec = pname;
    icon = pname;
    categories = [
      "Game"
      "Utility"
    ];
  };
in
pkgs.stdenvNoCC.mkDerivation {
  inherit pname version src;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/${pname}"
    install -Dm444 ${icon} "$out/share/icons/hicolor/scalable/apps/${pname}.svg"
    install -Dm444 ${desktopItem}/share/applications/${pname}.desktop \
      "$out/share/applications/${pname}.desktop"

    runHook postInstall
  '';

  meta = {
    description = "GUI downloader for Wii U titles hosted on Nintendo's servers";
    homepage = "https://github.com/Xpl0itU/WiiUDownloader";
    license = lib.licenses.gpl3Only;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
