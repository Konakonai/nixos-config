{ pkgs, ... }:

pkgs.stdenv.mkDerivation rec {
  pname = "codex";
  # Upstream pushes many alpha tags, some before their assets exist, and they
  # crowd stable releases out of nix-update's tag feed. Pass the stable version:
  #   nix-update --flake codex --version (gh release view -R openai/codex --json tagName -q '.tagName|ltrimstr("rust-v")')
  version = "0.163.0";

  src = pkgs.fetchurl {
    # The single-binary release asset lacks the code-mode host required by Codex Desktop.
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-package-x86_64-unknown-linux-musl.tar.zst";
    hash = "sha256-3yLawfJLeSfoF+ixEwZ/vhyqWGq6dVQkf6vUlGTPnJY=";
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

    # The default CLI starts a daemon, which discovers this package via its manifest.
    cp codex-package.json $out/

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
