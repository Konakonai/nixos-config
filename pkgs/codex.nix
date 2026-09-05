{ pkgs, lib, ... }:

pkgs.stdenv.mkDerivation rec {
  pname = "codex";
  version = "0.153.4";

  src = pkgs.fetchurl {
    # The single-binary release asset lacks the code-mode host required by Codex Desktop.
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-package-x86_64-unknown-linux-musl.tar.zst";
    sha256 = "sha256:2b5c00df5758d014c79910fdffed43f29a6cae73f37e92d5ec216543ca53e79e";
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
