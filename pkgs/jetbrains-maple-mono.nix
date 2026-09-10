{ pkgs, lib, ... }:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "jetbrains-maple-mono";
  version = "1.2304.79";

  src = pkgs.fetchurl {
    # The upstream release tag is reused when its generated font assets change.
    # Pin the GitHub asset ID so a later replacement fails instead of silently
    # resolving the same versioned URL to different contents.
    url = "https://api.github.com/repos/SpaceTimee/Fusion-JetBrainsMapleMono/releases/assets/518404936";
    curlOptsList = [
      "-H"
      "Accept: application/octet-stream"
    ];
    hash = "sha256-J0wbty9flOAI2cmywNHEIg7A86KpCRq289HhF4KDq/8=";
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
