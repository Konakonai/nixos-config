{ config, pkgs, ... }:

{
  # Hermes TUI skin auto-update — matches system Rose Pine palette.
  # Runs on every home-manager activation (i.e., every `rebuild`).
  # The script reads glass-settings.nix, detects light/dark, and sets
  # the corresponding Hermes skin (rose-pine-dawn or rose-pine).

  home.activation.updateHermesSkin = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    SKIN_SCRIPT="${config.home.homeDirectory}/.hermes/scripts/update-hermes-skin.py"
    if [ -x "$SKIN_SCRIPT" ]; then
      echo "hermes-skin: checking for palette changes..."
      ${pkgs.python3}/bin/python3 "$SKIN_SCRIPT"
    else
      echo "hermes-skin: update script not found or not executable, skipping" >&2
    fi
  '';
}
