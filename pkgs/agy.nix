{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
}:

let
  # The build ID in the URL comes from the release manifest:
  #   curl -fsSL https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_amd64.json
  # update-pins rewrites it.
  buildId = "6190022064472064";
in
stdenv.mkDerivation rec {
  pname = "agy";
  version = "1.5.7";

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${version}-${buildId}/linux-x64/cli_linux_x64.tar.gz";
    hash = "sha256-1hUKjSqeKaPRcbIyXW9mtucFlij0eZogwGm47Y94/bs=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 antigravity $out/libexec/agy
    # The CLI replaces its own binary in the background, which cannot work
    # in the read-only store; updates come from bumping this file instead.
    makeWrapper $out/libexec/agy $out/bin/agy \
      --set AGY_CLI_DISABLE_AUTO_UPDATE 1
    runHook postInstall
  '';

  meta = {
    description = "Google Antigravity CLI";
    homepage = "https://antigravity.google/product/antigravity-cli";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "agy";
  };
}
