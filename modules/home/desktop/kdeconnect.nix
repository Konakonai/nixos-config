{ lib, pkgs, ... }:

let
  refresh = pkgs.writeShellApplication {
    name = "kdeconnect-refresh";
    runtimeInputs = [ pkgs.coreutils pkgs.gnugrep pkgs.kdePackages.kdeconnect-kde ];
    text = builtins.readFile ../../../scripts/kdeconnect-refresh.sh;
  };
in
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

  # kdeconnectd already watches this computer's QNetworkInformation reachability.
  # That misses the common case: the phone changes Wi-Fi/cellular while the
  # laptop network stays up. --refresh is forceOnNetworkChange (re-broadcast
  # identity); it does not restart the daemon.
  #
  # Computer-side network events are handled by the NetworkManager dispatcher
  # in modules/system/programs.nix. This timer only broadcasts when no paired
  # device is currently reachable.
  systemd.user.services.kdeconnect-refresh = {
    Unit = {
      Description = "Refresh KDE Connect discovery if no device is reachable";
      After = [ "app-org.kde.kdeconnect.daemon@autostart.service" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe refresh} if-unreachable";
    };
  };

  systemd.user.timers.kdeconnect-refresh = {
    Unit.Description = "Recover KDE Connect after the phone changes networks";

    Timer = {
      OnStartupSec = "30s";
      OnUnitActiveSec = "2m";
      AccuracySec = "15s";
    };

    Install.WantedBy = [ "timers.target" ];
  };
}
