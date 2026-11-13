{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  fontconfig,
  ydotool,
}:

let
  pname = "computer-use-linux";
  version = "0.7.53";
  releaseBase = "https://github.com/agent-sh/computer-use-linux/releases/download/v${version}";

  mainBin = fetchurl {
    url = "${releaseBase}/computer-use-linux-x86_64-unknown-linux-musl";
    hash = "sha256-V1VHi9JMMe7xRhKhnmMMhWwkkFLw6Sd+6XK2ATjvthE=";
  };

  cosmicBin = fetchurl {
    url = "${releaseBase}/computer-use-linux-cosmic-x86_64-unknown-linux-musl";
    hash = "sha256-6t0OjB8W06acHeTnzm8i6jyCvspQx7Zs0uDDwxENVxM=";
  };

  indicatorBin = fetchurl {
    url = "${releaseBase}/computer-use-linux-indicator-x86_64-unknown-linux-musl";
    hash = "sha256-0bLVuQaVIkRCczmt8dskm5Is2ao3FvguKaKqhHJPtLY=";
  };

  src = fetchurl {
    url = "https://registry.npmjs.org/@agent-sh/computer-use-linux/-/computer-use-linux-${version}.tgz";
    hash = "sha256-Du42oK1OBqSvWT8z1Xbqho1+WeKXds6QbACHesrREHk=";
  };
in
stdenvNoCC.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [ makeWrapper ];

  # The npm tarball unpacks into `package/`.
  sourceRoot = "package";

  installPhase = ''
    runHook preInstall

    install -Dm755 "${mainBin}" "$out/libexec/computer-use-linux"
    install -Dm755 "${cosmicBin}" "$out/bin/computer-use-linux-cosmic"
    install -Dm755 "${indicatorBin}" "$out/libexec/computer-use-linux-indicator"

    # The indicator resolves system UI fonts by spawning `fc-match`.
    makeWrapper "$out/libexec/computer-use-linux-indicator" "$out/bin/computer-use-linux-indicator" \
      --prefix PATH : "${lib.makeBinPath [ fontconfig ]}"

    # Point the server at its Nix-packaged helpers and ensure ydotool stays
    # reachable even when launched with a minimal PATH.
    makeWrapper "$out/libexec/computer-use-linux" "$out/bin/computer-use-linux" \
      --set-default COMPUTER_USE_LINUX_COSMIC_HELPER "$out/bin/computer-use-linux-cosmic" \
      --set-default COMPUTER_USE_LINUX_INDICATOR_BIN "$out/bin/computer-use-linux-indicator" \
      --suffix PATH : "${lib.makeBinPath [ ydotool ]}"

    mkdir -p "$out/share/computer-use-linux"
    cp -R . "$out/share/computer-use-linux/"

    # Expose the packaged binaries under npm/bin so the Pi extension uses them
    # directly instead of attempting a runtime download into the read-only store.
    mkdir -p "$out/share/computer-use-linux/npm/bin"
    ln -s "$out/bin/computer-use-linux" \
      "$out/share/computer-use-linux/npm/bin/computer-use-linux-linux-x64"
    ln -s "$out/bin/computer-use-linux-cosmic" \
      "$out/share/computer-use-linux/npm/bin/computer-use-linux-cosmic"
    ln -s "$out/bin/computer-use-linux-indicator" \
      "$out/share/computer-use-linux/npm/bin/computer-use-linux-indicator"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/computer-use-linux" --help >/dev/null
    "$out/bin/computer-use-linux-cosmic" --help >/dev/null
    "$out/bin/computer-use-linux-indicator" --help >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Native Linux desktop control for AI agents over MCP, Pi native tools, and CLI";
    homepage = "https://github.com/agent-sh/computer-use-linux";
    license = lib.licenses.mit;
    mainProgram = "computer-use-linux";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
