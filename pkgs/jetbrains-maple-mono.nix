{ pkgs, lib, ... }:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "jetbrains-maple-mono";
  version = "1.2304.79";

  src = pkgs.fetchurl {
    url = "https://github.com/SpaceTimee/Fusion-JetBrainsMapleMono/releases/download/${version}/JetBrainsMapleMono-XX-XX-XX-HT.zip";
    hash = "sha256-e0+qq8YsoxM81EHKMyo3Xu5aKMaQON0USHR4ngngOuI=";
  };

  nativeBuildInputs = [ pkgs.unzip ];

  unpackPhase = ''
    runHook preUnpack
    unzip "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    install -Dm444 *.ttf -t "$out/share/fonts/truetype"
    runHook postInstall
  '';

  meta = {
    description = "JetBrains Mono fused with Maple Mono CJK glyphs";
    homepage = "https://github.com/SpaceTimee/Fusion-JetBrainsMapleMono";
    license = lib.licenses.ofl;
    platforms = [ "x86_64-linux" ];
  };
}
