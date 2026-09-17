{
  pkgs,
  lib,
  braveOrigin ? import ./brave-origin.nix { inherit pkgs lib; },
  ...
}:

let
  operaUserAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36 OPR/120.0.0.0";
  widevinePath = "${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm";

  launcher = pkgs.writeShellApplication {
    name = "brave-netflix-opera";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      profile_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/brave-netflix-opera"
      if [ ! -e "$profile_dir/SingletonLock" ]; then
        mkdir -p "$profile_dir/WidevineCdm"
        printf '{"Path":%s}' "$(jq -Rn --arg path ${lib.escapeShellArg widevinePath} '$path')" \
          > "$profile_dir/WidevineCdm/latest-component-updated-widevine-cdm"

        local_state="$profile_dir/Local State"
        if [ -s "$local_state" ]; then
          tmp_state="$(mktemp "$profile_dir/local-state.XXXXXX")"
          jq '.brave.widevine_opted_in = true' "$local_state" > "$tmp_state"
          mv "$tmp_state" "$local_state"
        else
          printf '{"brave":{"widevine_opted_in":true}}\n' > "$local_state"
        fi
      fi

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
    categories = [
      "AudioVideo"
      "Network"
    ];
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
