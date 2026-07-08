{ pkgs, lib, braveOrigin ? import ./brave-origin.nix { inherit pkgs lib; }, ... }:

let
  operaUserAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36 OPR/120.0.0.0";

  launcher = pkgs.writeShellApplication {
    name = "brave-netflix-opera";
    text = ''
      profile_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/brave-netflix-opera"
      mkdir -p "$profile_dir"

      if [ "$#" -eq 0 ]; then
        set -- "https://www.netflix.com/browse"
      fi

      exec ${lib.getExe braveOrigin} \
        --user-data-dir="$profile_dir" \
        --user-agent=${lib.escapeShellArg operaUserAgent} \
        "$@"
    '';
  };

  desktopItem = pkgs.makeDesktopItem {
    name = "brave-netflix-opera";
    desktopName = "Netflix";
    genericName = "Netflix in Brave";
    comment = "Open Netflix in Brave with an Opera user agent";
    exec = lib.getExe launcher;
    icon = "brave-origin";
    categories = [ "AudioVideo" "Network" ];
    startupNotify = true;
  };
in
pkgs.symlinkJoin {
  name = "brave-netflix-opera";
  paths = [
    launcher
    desktopItem
  ];

  meta = {
    description = "Netflix launcher for Brave Origin with an Opera user agent";
    license = lib.licenses.mit;
    mainProgram = "brave-netflix-opera";
    platforms = [ "x86_64-linux" ];
  };
}
