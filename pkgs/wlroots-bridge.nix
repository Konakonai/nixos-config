{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

let
  rev = "32aafe4cce4932e20e79f2590f31688dbb79cf1a";
in
rustPlatform.buildRustPackage {
  pname = "wlroots-bridge";
  version = "0.1.0-unstable-2026-11-13";

  src = fetchFromGitHub {
    owner = "patrickjaja";
    repo = "wlroots-bridge";
    inherit rev;
    hash = "sha256-KUHQBrCPl5qWCPbWYNH5WjoT3WZ7wjyQ6tu9vf7C0kU=";
  };

  cargoHash = "sha256-tN2vpFrFIJOkt5oJxY31XiE/bseZmsNDbsWdz496UOo=";

  # Integration tests requiring a running Sway compositor are skipped unless
  # WLROOTS_BRIDGE_REQUIRE_SWAY=1 is set; pure unit tests run normally.
  # The two failure_after_bind_leaves_nothing_behind mock tests rely on
  # permission-based bind failures that do not trigger inside Nix's sandbox.
  doCheck = true;
  checkFlags = [
    "--skip=hypr_failure_after_bind_leaves_nothing_behind"
    "--skip=sway_failure_after_bind_leaves_nothing_behind"
  ];

  meta = {
    description = "Pure-Rust wlroots-Wayland bridge for Linux computer-use automation";
    homepage = "https://github.com/patrickjaja/wlroots-bridge";
    license = lib.licenses.mit;
    mainProgram = "wlroots-bridge";
    platforms = lib.platforms.linux;
  };
}
