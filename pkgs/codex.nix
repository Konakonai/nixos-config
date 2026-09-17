{ pkgs, ... }:

pkgs.stdenv.mkDerivation rec {
  pname = "codex";
  version = "0.154.0";

  src = pkgs.fetchurl {
    # The single-binary release asset lacks the code-mode host required by Codex Desktop.
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-package-x86_64-unknown-linux-musl.tar.zst";
    sha256 = "sha256:68841a983ff470ae5b84922490b254a53723415e31dd8b8ea7b0811addb0086d";
  };

  sourceRoot = ".";

  nativeBuildInputs = [ pkgs.zstd ];

  installPhase = ''
    mkdir -p $out/bin
    if [ -d bin ]; then
      cp -a bin/* $out/bin/
    else
      cp codex $out/bin/codex
      cp codex-code-mode-host $out/bin/codex-code-mode-host
    fi
    chmod +x $out/bin/codex $out/bin/codex-code-mode-host

    if [ -d codex-resources ]; then
      cp -R codex-resources $out/
    fi
    if [ -d codex-path ]; then
      cp -R codex-path $out/
    fi
  '';

  meta = {
    description = "Lightweight coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    platforms = [ "x86_64-linux" ];
  };
}
