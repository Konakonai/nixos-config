{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "cc-switch-cli";
  version = "5.8.2";

  src = pkgs.fetchurl {
    url = "https://github.com/SaladDay/cc-switch-cli/releases/download/v${version}/cc-switch-cli-linux-x64.tar.gz";
    hash = "sha256-XHxBIUPhDc02WWjRno0mXkRpEbWV/dGk6AxHX1b36JM=";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 cc-switch "$out/bin/cc-switch"

    runHook postInstall
  '';

  meta = {
    description = "TUI and CLI manager for Claude Code, Codex, Gemini, OpenCode, Hermes, and OpenClaw";
    homepage = "https://github.com/SaladDay/cc-switch-cli";
    license = pkgs.lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "cc-switch";
  };
}
