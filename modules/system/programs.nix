{
  lib,
  pkgs,
  hostProfile,
  ...
}:

let
  askPass = lib.getExe' pkgs.kdePackages.ksshaskpass "ksshaskpass";
  userName = hostProfile.user.userName;
  kdeconnectRefresh = pkgs.writeShellApplication {
    name = "kdeconnect-refresh";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.kdePackages.kdeconnect-kde
    ];
    text = builtins.readFile ../../scripts/kdeconnect-refresh.sh;
  };
  kdeconnectNmHook = pkgs.writeShellScript "kdeconnect-nm-refresh" ''
    set -euo pipefail
    case "''${2:-}" in
      up|vpn-up|connectivity-change|dhcp4-change|dhcp6-change) ;;
      *) exit 0 ;;
    esac

    uid="$(${pkgs.coreutils}/bin/id -u ${lib.escapeShellArg userName})"
    bus="/run/user/$uid/bus"
    if [ ! -S "$bus" ]; then
      exit 0
    fi

    # DHCP/Wi-Fi association can finish before the phone is reachable again.
    ${pkgs.coreutils}/bin/sleep 2
    ${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg userName} -- \
      ${pkgs.coreutils}/bin/env \
        XDG_RUNTIME_DIR="/run/user/$uid" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
        ${lib.getExe kdeconnectRefresh} always
  '';
in
{
  hardware.xpadneo.enable = true;

  programs.steam = {
    enable = true;
    package = pkgs.millennium-steam.override {
      extraEnv.FONTCONFIG_FILE = "${hostProfile.user.homeDirectory}/.config/fontconfig/steam.conf";
    };
    extraPackages = with pkgs; [
      pulseaudio
    ];
    remotePlay.openFirewall = true;
  };

  programs.gamemode.enable = true;
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };
  programs.kdeconnect.enable = true;

  # Computer network changes are not always delivered through Qt's
  # QNetworkInformation (sleep/resume, VPN, interface swap). Tell kdeconnectd
  # immediately instead of waiting for the unreachable-device timer.
  networking.networkmanager.dispatcherScripts = [
    {
      source = kdeconnectNmHook;
      type = "basic";
    }
  ];
  programs.fish.enable = true;
  programs.nix-ld.enable = true;
  programs.ssh.askPassword = askPass;

  environment.systemPackages = [
    pkgs.kdePackages.ksshaskpass
  ];

  environment.variables = {
    GIT_ASKPASS = askPass;
    # Applications that bundle their own git binary (editors, agents) still
    # resolve helpers such as git-remote-https from the system git-core.
    GIT_EXEC_PATH = "${pkgs.git}/libexec/git-core";
  };
}
