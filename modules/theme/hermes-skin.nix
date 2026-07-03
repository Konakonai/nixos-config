{ config, pkgs, ... }:

{
  # Hermes TUI skin auto-update — generates from Noctalia's palette.
  # Noctalia outputs its computed colors to ~/.cache/noctalia/starship-palette.toml
  # on every rebuild. This activation hook reads those actual colors and
  # generates ~/.hermes/skins/noctalia.yaml, then sets the active skin to 'noctalia'.
  #
  # The skin dynamically tracks all palette changes (accent, background, text,
  # surface layers, etc.) — not just a binary light/dark switch.

  home.activation.updateHermesSkin = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    SKIN_SCRIPT="${config.home.homeDirectory}/.hermes/scripts/update-hermes-skin.py"
    if [ -x "$SKIN_SCRIPT" ]; then
      echo "hermes-skin: generating from Noctalia palette..."
      ${pkgs.python3}/bin/python3 "$SKIN_SCRIPT"
    else
      echo "hermes-skin: script not found or not executable, skipping" >&2
    fi
  '';
}
