{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage {
  pname = "wlroots-bridge";
  version = "0.1.0-unstable-2026-10-26";

  src = fetchFromGitHub {
    owner = "patrickjaja";
    repo = "wlroots-bridge";
    rev = "57dd88f2e97da7b383c77889776b2963bf1408f0";
    hash = "sha256-1z0R2zrHSO9t9FJBCf0l+02ohpAUqF46Y5vEQi/zxOg=";
  };

  cargoHash = "sha256-RXjsWwI2TkiwQWXRgsL2BReCNl+T7ygcNdLO7ALTsmk=";

  # Two input bugs on sway that niri hides, both leaving Claude's headless
  # sway (modules/home/apps/desktop.nix) unusable:
  # - Each call creates a fresh virtual pointer/keyboard and sends its events in
  #   the same burst. sway removes a seat capability whenever no device provides
  #   it, so the events arrive before clients have re-bound wl_pointer /
  #   wl_keyboard: clicks are lost and the first key of every call is dropped.
  #   Wait for the compositor and give clients a moment first.
  # - wlroots does not derive modifier state from a virtual keyboard's keys, so
  #   `ctrl+c` arrived as `c`. Report the modifier mask explicitly.
  patches = [ ./wlroots-bridge-sway-input.patch ];

  meta = {
    description = "wlroots Wayland bridge for Claude Desktop Computer Use on Linux";
    homepage = "https://github.com/patrickjaja/wlroots-bridge";
    license = lib.licenses.mit;
    mainProgram = "wlroots-bridge";
    platforms = lib.platforms.linux;
  };
}
