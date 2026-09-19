{ pkgs, ... }:

pkgs.stdenv.mkDerivation rec {
  pname = "codex";
  version = "0.155.1";

  src = pkgs.fetchurl {
    # The single-binary release asset lacks the code-mode host required by Codex Desktop.
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-package-x86_64-unknown-linux-musl.tar.zst";
    sha256 = "sha256:8312d172da663e4eb4b809447dcf12e248d5174ae18d68e54bbd4c92d37bd8ae";
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
