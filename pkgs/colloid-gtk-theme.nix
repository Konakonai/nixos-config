{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  sassc,
  gnused,
  coreutils,
  findutils,
  jdupes,
  glib,
  themeVariants ? [ "default" "purple" ],
  colorVariants ? [ "light" "standard" ],
  sizeVariants ? [ "standard" ],
  tweaks ? [ "rimless" ],
}:

stdenvNoCC.mkDerivation rec {
  pname = "colloid-gtk-theme";
  version = "2025-07-19";

  src = fetchFromGitHub {
    owner = "vinceliuice";
    repo = "Colloid-gtk-theme";
    rev = "main";
    hash = "sha256-dkYd1GVYL0VmiQAPx7XHQtDWym44O0kpqVYhgvvLDNg=";
  };

  nativeBuildInputs = [
    sassc
    gnused
    coreutils
    findutils
    jdupes
    glib
  ];

  dontDropIconThemeCache = true;

  postPatch = ''
    patchShebangs install.sh gtkrc.sh assets.sh
  '';

  installPhase = ''
    runHook preInstall

    name=Colloid \
    ./install.sh \
      --dest "$out/share/themes" \
      ${lib.optionalString (themeVariants != [ ]) "--theme " + lib.concatStringsSep " " themeVariants} \
      ${lib.optionalString (colorVariants != [ ]) "--color " + lib.concatStringsSep " " colorVariants} \
      ${lib.optionalString (sizeVariants != [ ]) "--size " + lib.concatStringsSep " " sizeVariants} \
      ${lib.optionalString (tweaks != [ ]) "--tweaks " + lib.concatStringsSep " " tweaks}

    jdupes -q -r -L "$out/share/themes"

    runHook postInstall
  '';

  meta = {
    description = "A modern and clean Gtk theme with macOS-like round elements";
    homepage = "https://github.com/vinceliuice/Colloid-gtk-theme";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.unix;
  };
}
