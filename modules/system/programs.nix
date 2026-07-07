{ lib, pkgs, ... }:

let
  askPass = lib.getExe' pkgs.kdePackages.ksshaskpass "ksshaskpass";
  steamBootstrapperLocalePatch = ''
    steam_public="$HOME/.local/share/Steam/public"
    steam_bootstrapper_english="$steam_public/steambootstrapper_english.txt"
    steam_bootstrapper_schinese="$steam_public/steambootstrapper_schinese.txt"

    if [ -r "$steam_bootstrapper_english" ] && [ -d "$steam_public" ]; then
      steam_bootstrapper_tmp="$(mktemp)"
      sed '1s/"Language"[[:space:]]*"english"/"Language" "schinese"/' \
        "$steam_bootstrapper_english" > "$steam_bootstrapper_tmp"

      if ! cmp -s "$steam_bootstrapper_tmp" "$steam_bootstrapper_schinese"; then
        if [ -f "$steam_bootstrapper_schinese" ] \
          && grep -q 'SteamBootstrapper_UpdateChecking.*正在检查可用更新' "$steam_bootstrapper_schinese"
        then
          cp -f "$steam_bootstrapper_schinese" "$steam_bootstrapper_schinese.nixos-original"
        fi

        cp -f "$steam_bootstrapper_tmp" "$steam_bootstrapper_schinese"
      fi

      rm -f "$steam_bootstrapper_tmp"
    fi
  '';
in
{
  hardware.xpadneo.enable = true;

  programs.steam = {
    enable = true;
    package = pkgs.millennium-steam.override {
      extraProfile = steamBootstrapperLocalePatch;
    };
    extraPackages = with pkgs; [
      pulseaudio
    ];
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  programs.gamemode.enable = true;
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };
  programs.kdeconnect.enable = true;
  programs.fish.enable = true;
  programs.nix-ld.enable = true;
  programs.ssh.askPassword = askPass;

  environment.systemPackages = [
    pkgs.kdePackages.ksshaskpass
  ];

  environment.variables = {
    GIT_ASKPASS = askPass;
    GIT_EXEC_PATH = "${pkgs.git}/libexec/git-core";
  };
}
