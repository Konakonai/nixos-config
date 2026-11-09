{ pkgs, lib, ... }:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "jetbrains-maple-mono";
  version = "1.2304.79";

  src = pkgs.fetchurl {
    # Upstream re-uploads assets under a reused tag; the hash catches that.
    # Not the API asset URL: anonymous API calls share a 60/hour quota per
    # exit IP, which the proxy exhausts.
    url = "https://github.com/SpaceTimee/Fusion-JetBrainsMapleMono/releases/download/${version}/JetBrainsMapleMono-XX-XX-XX-HT.zip";
    hash = "sha256-1rWoD1AkwVifwa6Y+swaF5g27rwCQKxZaB41U68Dhcg=";
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
