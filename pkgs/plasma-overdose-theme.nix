{
  fetchurl,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "plasma-overdose-theme";
  version = "0-unstable-2026-04-23";

  src = fetchurl {
    url = "https://codeberg.org/Notify-ctrl/Plasma-Overdose/archive/2ca54efdeef230277294a04b0124c5572a16de0b.tar.gz";
    hash = "sha256-85nEHmDzeAERZNc1zB/yuqR/M0DSQ6VpJSUSy/3j3Dk=";
  };

  postPatch = ''
    substituteInPlace aurorae/Plasma-Overdose/Plasma-Overdoserc \
      --replace-fail "BorderLeft=5" "BorderLeft=8" \
      --replace-fail "BorderRight=5" "BorderRight=8" \
      --replace-fail "BorderBottom=5" "BorderBottom=8" \
      --replace-fail "TitleEdgeLeft=7" "TitleEdgeLeft=8" \
      --replace-fail "TitleEdgeRight=7" "TitleEdgeRight=8" \
      --replace-fail "TitleHeight=18" "TitleHeight=16"
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p \
      "$out/share/aurorae/themes" \
      "$out/share/color-schemes" \
      "$out/share/icons/Plasma-Overdose" \
      "$out/share/konsole" \
      "$out/share/kwin/decorations" \
      "$out/share/plasma/desktoptheme" \
      "$out/share/plasma/look-and-feel" \
      "$out/share/sounds" \
      "$out/share/wallpapers"

    cp -r aurorae/Plasma-Overdose* "$out/share/aurorae/themes/"
    cp PlasmaOverdose.colors "$out/share/color-schemes/"
    cp -r cursors/. "$out/share/icons/Plasma-Overdose/"
    cp konsole/Plasma-Overdose.colorscheme "$out/share/konsole/"
    cp -r kwin/Plasma-Overdose-KWinDeco "$out/share/kwin/decorations/"
    cp -r plasma/desktoptheme/Plasma-Overdose "$out/share/plasma/desktoptheme/"
    cp -r plasma/look-and-feel/Plasma-Overdose "$out/share/plasma/look-and-feel/"
    cp -r sounds/. "$out/share/sounds/PlasmaOverdose/"
    cp -r wallpapers/. "$out/share/wallpapers/Plasma-Overdose/"

    runHook postInstall
  '';

  meta = {
    description = "Plasma Overdose desktop, window, cursor, sound, and terminal theme";
    homepage = "https://codeberg.org/Notify-ctrl/Plasma-Overdose";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.all;
  };
}
