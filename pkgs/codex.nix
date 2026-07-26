{ pkgs, lib, ... }:

pkgs.stdenv.mkDerivation rec {
  pname = "codex";
  version = "0.145.0";

  src = pkgs.fetchurl {
    # The single-binary release asset lacks the code-mode host required by Codex Desktop.
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl-bundle.tar.zst";
    sha256 = "sha256:2ff38e8fa6fb7709292963ff133cd665ef8511d0954fbb3cdd03d804c334c36d";
  };

  sourceRoot = ".";

  nativeBuildInputs = [ pkgs.zstd ];

  installPhase = ''
    mkdir -p $out/bin
    cp codex $out/bin/codex
    cp codex-code-mode-host $out/bin/codex-code-mode-host
    chmod +x $out/bin/codex $out/bin/codex-code-mode-host

    if [ -d codex-resources ]; then
      cp -R codex-resources $out/
    fi
  '';

  meta = {
    description = "Lightweight coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    platforms = [ "x86_64-linux" ];
  };
}
