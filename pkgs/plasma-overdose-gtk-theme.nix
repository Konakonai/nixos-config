{
  fetchFromGitHub,
  imagemagick,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "plasma-overdose-gtk-theme";
  version = "0-unstable-2023-06-21";

  src = fetchFromGitHub {
    owner = "B00merang-Project";
    repo = "Windows-95";
    rev = "055abd7a3608afdcb2ef021732e07020f2b416b2";
    hash = "sha256-f57OhcjCCxxnJszRSUVnndh6TYIhzo5QaAn4Yf3nJtI=";
  };

  nativeBuildInputs = [ imagemagick ];

  postPatch = ''
    # Retain the Windows 95 widget geometry while translating its grey/navy
    # palette to Plasma Overdose's light pink and violet design language.
    while IFS= read -r themeFile; do
      substituteInPlace "$themeFile" \
        --replace "#000080" "#712aff" \
        --replace "#000000" "#4d21cb" \
        --replace "#C0C0C0" "#fcf0fd" \
        --replace "#c0c0c0" "#fcf0fd" \
        --replace "#ececec" "#ffffff" \
        --replace "#7d7d7d" "#a3c6ee" \
        --replace "#606060" "#7b7b7a" \
        --replace "#b6b6b6" "#f6e0f8" \
        --replace "rgba(192, 192, 192," "rgba(252, 240, 253," \
        --replace "rgba(0, 0, 128," "rgba(113, 42, 255,"
    done < <(
      find gtk-2.0 gtk-3.0 gtk-4.0 -type f \
        \( -name '*.css' -o -name '*.rc' -o -name 'gtkrc' \)
    )

    while IFS= read -r asset; do
      magick mogrify \
        -fill "#4d21cb" -opaque "#000000" \
        -fill "#712aff" -opaque "#000080" \
        -fill "#fcf0fd" -opaque "#c0c0c0" \
        -fill "#a3c6ee" -opaque "#808080" \
        "$asset"
    done < <(find gtk-2.0 gtk-3.0 gtk-4.0 -type f -name '*.png')

    substituteInPlace index.theme \
      --replace-fail "Name=Windows 95" "Name=Plasma Overdose GTK" \
      --replace-fail "Comment=Windows 95 UI for Linux OSes" "Comment=Plasma Overdose colors with Windows 95 widgets" \
      --replace-fail "GtkTheme=Windows 95" "GtkTheme=Plasma-Overdose-GTK" \
      --replace-fail "IconTheme=Chicago95" "IconTheme=Tela" \
      --replace-fail "CursorTheme=DMZ-White" "CursorTheme=Plasma-Overdose"
  '';

  installPhase = ''
    runHook preInstall

    themeDir="$out/share/themes/Plasma-Overdose-GTK"
    mkdir -p "$themeDir"
    cp -r gtk-2.0 gtk-3.0 gtk-4.0 index.theme "$themeDir/"

    runHook postInstall
  '';

  meta = {
    description = "Windows 95 GTK widgets recolored for Plasma Overdose";
    homepage = "https://github.com/B00merang-Project/Windows-95";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.all;
  };
}
