{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
}:

stdenv.mkDerivation rec {
  pname = "agy";
  # The build ID in the URL comes from the release manifest:
  #   curl -fsSL https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_amd64.json
  version = "1.5.1";

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${version}-4523430503120896/linux-x64/cli_linux_x64.tar.gz";
    hash = "sha256-KmTM/F9mecJTdp8HYGFK9d4E2Nwe7uybl1K6TI3ZIlA=";
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
