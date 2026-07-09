{ pkgs ? import <nixpkgs> {} }:

pkgs.rustPlatform.buildRustPackage rec {
  pname = "cc-switch-cli";
  version = "5.8.2";

  src = pkgs.fetchFromGitHub {
    owner = "SaladDay";
    repo = "cc-switch-cli";
    tag = "v${version}";
    hash = "sha256-Pwqc2VVHhCZwbpJ4lvhZA4m+OK6ry6ZO20RuQ3A7fek=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";
  cargoHash = "sha256-f3d+jPVsO7Y+voK5/bcMsQbHe4f2lEbnzFOuVwyCOOA=";

  patches = [
    ../../patches/cc-switch-cli-noctalia-theme.patch
  ];

  # Upstream's full release test suite is heavy; system builds only need the CLI.
  doCheck = false;

  meta = {
    description = "TUI and CLI manager for Claude Code, Codex, Gemini, OpenCode, Hermes, and OpenClaw";
    homepage = "https://github.com/SaladDay/cc-switch-cli";
    license = pkgs.lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "cc-switch";
  };
}
