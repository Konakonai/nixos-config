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

    mkdir -p "$out/share/plasma/desktoptheme" "$out/share/color-schemes" "$out/share/plasma/look-and-feel" "$out/share/aurorae/themes" "$out/share/wallpapers" "$out/share/sddm/themes/MacTahoe-Light" "$out/share/sddm/themes/MacTahoe-Dark"

    cp -r color-schemes/* "$out/share/color-schemes/" 2>/dev/null || true
    cp -r plasma/desktoptheme/* "$out/share/plasma/desktoptheme/" 2>/dev/null || true
    cp -r plasma/look-and-feel/* "$out/share/plasma/look-and-feel/" 2>/dev/null || true
    cp -r wallpapers/* "$out/share/wallpapers/" 2>/dev/null || true

    cp -r sddm/MacTahoe-6.0/* "$out/share/sddm/themes/MacTahoe-Light/"
    cp -r sddm/images/Background-Light.jpeg "$out/share/sddm/themes/MacTahoe-Light/Background.jpeg"
    cp -r sddm/images/Preview-Light.jpeg "$out/share/sddm/themes/MacTahoe-Light/Preview.jpeg"

    cp -r sddm/MacTahoe-6.0/* "$out/share/sddm/themes/MacTahoe-Dark/"
    cp -r sddm/images/Background-Dark.jpeg "$out/share/sddm/themes/MacTahoe-Dark/Background.jpeg"
    cp -r sddm/images/Preview-Dark.jpeg "$out/share/sddm/themes/MacTahoe-Dark/Preview.jpeg"

    runHook postInstall
  '';

  meta = {
    description = "MacTahoe theme for KDE Plasma desktop";
    homepage = "https://github.com/vinceliuice/MacTahoe-kde";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.unix;
  };
}
