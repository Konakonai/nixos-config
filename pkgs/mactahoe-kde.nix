{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation rec {
  pname = "mactahoe-kde";
  version = "2024-11-20";

  src = fetchFromGitHub {
    owner = "vinceliuice";
    repo = "MacTahoe-kde";
    rev = "main";
    hash = "sha256-atdHgr9pCfg/VE8GGWF+4MZu6nRmVCz9TiylVATAwzs=";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/plasma/desktoptheme" "$out/share/color-schemes" "$out/share/plasma/look-and-feel" "$out/share/aurorae/themes" "$out/share/wallpapers"

    cp -r color-schemes/* "$out/share/color-schemes/" 2>/dev/null || true
    cp -r plasma/desktoptheme/* "$out/share/plasma/desktoptheme/" 2>/dev/null || true
    cp -r plasma/look-and-feel/* "$out/share/plasma/look-and-feel/" 2>/dev/null || true
    cp -r wallpapers/* "$out/share/wallpapers/" 2>/dev/null || true

    runHook postInstall
  '';

  meta = {
    description = "MacTahoe theme for KDE Plasma desktop";
    homepage = "https://github.com/vinceliuice/MacTahoe-kde";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.unix;
  };
}
