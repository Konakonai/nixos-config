{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation {
  pname = "noctalia-mihomo-control";
  version = "0.2.1";

  src = fetchFromGitHub {
    owner = "noctalia-dev";
    repo = "community-plugins";
    rev = "bbf33787769a5c93ba02a8d17bd5faac43c4f9ba";
    sparseCheckout = [ "mihomo-control" ];
    hash = "sha256-dM5IsLlzgyv+Xa1O/PfjB4FezLS3kR4pd1cCuJb4trQ=";
  };

  sourceRoot = "source/mihomo-control";

  # Keep local card layout tweaks, hide internal (`hidden: true`) Mihomo groups,
  # and avoid Noctalia warning logs (color token & reserved setting key).
  patches = [ ../patches/noctalia-mihomo-control.patch ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r . "$out/"
    runHook postInstall
  '';

  meta = {
    description = "Noctalia Mihomo Control plugin with local layout and hidden-group patches";
    homepage = "https://github.com/noctalia-dev/community-plugins/tree/main/mihomo-control";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
