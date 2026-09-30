{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  # "lilya_lckstar喜欢的音乐" on NetEase; public, readable without login.
  likedPlaylist = "2331288123";
  stateDir = "${config.xdg.stateHome}/music-discover";
  python = pkgs.python3.withPackages (p: [
    p.opencc
    p.ytmusicapi
  ]);

  # Runs on the laptop, not the server: YouTube Music is only reachable
  # through mihomo. The page is then served by the Navidrome nginx at
  # https://106.14.0.229:8443/discover/ (see docs/music-server.md).
  music-discover = pkgs.writeShellApplication {
    name = "music-discover";
    runtimeInputs = with pkgs; [
      openssh
      rsync
    ];
    text = ''
      ${python}/bin/python3 ${../../scripts/music-discover.py} \
        --playlist ${likedPlaylist} \
        --library-db ${config.programs.beets.settings.library} \
        --state ${stateDir} \
        --out ${stateDir}/site \
        --cookie-file ${osConfig.age.secrets.netease-cookie.path}
      rsync -a --chmod=D755,F644 ${stateDir}/site/ shanghai:/var/www/discover/
      echo "music-discover: https://106.14.0.229:8443/discover/"
    '';
  };
in
{
  home.packages = [ music-discover ];

  systemd.user.services.music-discover = {
    Unit.Description = "Build the weekly music discovery page";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe music-discover;
    };
  };

  systemd.user.timers.music-discover = {
    Unit.Description = "Weekly music discovery page";
    Timer = {
      OnCalendar = "Mon 09:00";
      # Catch up after the laptop was off at the scheduled time.
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
