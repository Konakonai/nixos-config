{ lib, pkgs, ... }:

{
  xdg.desktopEntries."kdeconnect-browser" = {
    name = "Browse KDE Connect Device";
    exec = "${lib.getExe pkgs.kdePackages.dolphin} %U";
    icon = "kdeconnect";
    type = "Application";
    terminal = false;
    noDisplay = true;
    mimeType = [ "x-scheme-handler/kdeconnect" ];
  };

  # Network discovery can be missed while the phone or Wi-Fi is waking up.
  # This is equivalent to pressing Retry in KDE Connect and does not restart
  # the daemon or interrupt an existing connection.
  systemd.user.services.kdeconnect-refresh = {
    Unit = {
      Description = "Refresh KDE Connect device discovery";
      After = [ "app-org.kde.kdeconnect.daemon@autostart.service" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnect-cli --refresh";
    };
  };

  systemd.user.timers.kdeconnect-refresh = {
    Unit.Description = "Periodically refresh KDE Connect device discovery";

    Timer = {
      OnStartupSec = "30s";
      OnUnitActiveSec = "2m";
      AccuracySec = "15s";
    };

    Install.WantedBy = [ "timers.target" ];
  };
}
