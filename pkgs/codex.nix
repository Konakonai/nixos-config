{ pkgs, ... }:

pkgs.stdenv.mkDerivation rec {
  pname = "codex";
  # Match the upstream tag so nix-update can update this package directly.
  version = "rust-v0.157.1";

  src = pkgs.fetchurl {
    # The single-binary release asset lacks the code-mode host required by Codex Desktop.
    url = "https://github.com/openai/codex/releases/download/${version}/codex-package-x86_64-unknown-linux-musl.tar.zst";
    sha256 = "sha256:sha256-9D+bmwubY2jdyXt31Ddpba/MrKc2ANRt9bipszyKUCo=";
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
