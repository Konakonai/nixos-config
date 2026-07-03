{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "orchis-kde";
  version = "2025-10-18";

  src = fetchFromGitHub {
    owner = "vinceliuice";
    repo = "Orchis-kde";
    rev = "b2a96919eee40264e79db402b915f926436100ad";
    hash = "sha256-mO1AVrnXNdg3Rftj0cQWef/RrBgSDy5kaMHagwKywEo=";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/Kvantum" "$out/share/color-schemes"
    cp -r Kvantum/Orchis Kvantum/Orchis-solid "$out/share/Kvantum/"
    cp color-schemes/Orchis.colors color-schemes/OrchisDark.colors "$out/share/color-schemes/"

    runHook postInstall
  '';

  meta = {
    description = "Orchis KDE Kvantum themes and color schemes";
    homepage = "https://github.com/vinceliuice/Orchis-kde";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
