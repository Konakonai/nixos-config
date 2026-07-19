{
  fetchurl,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "plasma-overdose-cursors";
  version = "0-unstable-2026-04-23";

  src = fetchurl {
    url = "https://codeberg.org/Notify-ctrl/Plasma-Overdose/archive/2ca54efdeef230277294a04b0124c5572a16de0b.tar.gz";
    hash = "sha256-85nEHmDzeAERZNc1zB/yuqR/M0DSQ6VpJSUSy/3j3Dk=";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/icons/Plasma-Overdose"
    cp -r cursors/. "$out/share/icons/Plasma-Overdose/"

    runHook postInstall
  '';

  meta = {
    description = "Cursor theme from Plasma Overdose";
    homepage = "https://codeberg.org/Notify-ctrl/Plasma-Overdose";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.all;
  };
}
