{ pkgs, lib, ... }:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "genryumin";
  version = "2.100";

  # TC 是传承字形版，和霞鹜文楷 TC 的字形一致；TW 版按台湾教育部标准字形。
  src = pkgs.fetchurl {
    url = "https://github.com/ButTaiwan/genryu-font/releases/download/v${version}/GenRyuMin2TC-otf.zip";
    hash = "sha256-c5D9VAEDKKd+tbS/jfW5LZt9diIItimVVcspK3j2xvE=";
  };

  nativeBuildInputs = [ pkgs.unzip ];

  unpackPhase = ''
    runHook preUnpack
    unzip "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    install -Dm444 *.otf -t "$out/share/fonts/opentype"
    runHook postInstall
  '';

  meta = {
    description = "GenRyuMin, a traditional-orthography Ming typeface based on Source Han Serif";
    homepage = "https://github.com/ButTaiwan/genryu-font";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
}
