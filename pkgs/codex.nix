{ pkgs, lib, ... }:

pkgs.stdenv.mkDerivation rec {
  pname = "codex";
  version = "0.146.0";

  src = pkgs.fetchurl {
    # The single-binary release asset lacks the code-mode host required by Codex Desktop.
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl-bundle.tar.zst";
    sha256 = "sha256:9ed583d1bf8589765ca7b8bcbe12a42cf651bd324f8cb7d37d83121418e87558";
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
