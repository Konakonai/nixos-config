{
  lib,
  pkgs,
  hostProfile,
  ...
}:

let
  askPass = lib.getExe' pkgs.kdePackages.ksshaskpass "ksshaskpass";
  userName = hostProfile.user.userName;
  # Only re-arms the timer below and returns: the dispatcher runs its scripts
  # one event at a time, and a connect fires several of these events in a row.
  kdeconnectNmHook = pkgs.writeShellScript "kdeconnect-nm-refresh" ''
    case "''${2:-}" in
      up|vpn-up|connectivity-change|dhcp4-change|dhcp6-change) ;;
      *) exit 0 ;;
    esac
    exec ${pkgs.systemd}/bin/systemctl restart --no-block kdeconnect-nm-refresh.timer
  '';
  kdeconnectNmRefresh = pkgs.writeShellScript "kdeconnect-nm-refresh-run" ''
    runtime="/run/user/$(${pkgs.coreutils}/bin/id -u)"
    [ -S "$runtime/bus" ] || exit 0
    export XDG_RUNTIME_DIR="$runtime" DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus"
    exec ${lib.getExe pkgs.lilya.kdeconnect-refresh} always
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
  # Each event restarts the timer, so a burst of them ends in one refresh. The
  # 2 s also covers DHCP/Wi-Fi association finishing before the phone is
  # reachable again.
  systemd.timers.kdeconnect-nm-refresh.timerConfig = {
    OnActiveSec = "2s";
    AccuracySec = "100ms";
    RemainAfterElapse = false;
  };
  systemd.services.kdeconnect-nm-refresh = {
    description = "Refresh KDE Connect discovery after a network change";
    serviceConfig = {
      Type = "oneshot";
      User = userName;
      ExecStart = kdeconnectNmRefresh;
    };
  };
  programs.fish.enable = true;
  programs.vim = {
    enable = true;
    defaultEditor = true;
  };
  programs.nix-ld.enable = true;
  # Codex runs with sandbox_mode = "danger-full-access", so its cached generic
  # Linux runtimes bypass the bwrap adapter that codex-desktop-linux uses to
  # inject libraries and load through the system nix-ld instead. The primary
  # runtime's headless LibreOffice needs these on top of the nix-ld defaults.
  programs.nix-ld.libraries = with pkgs; [
    fontconfig
    freetype
    lcms2
    nspr
    nss
  ];
  programs.ssh.askPassword = askPass;

  # Codex Linux Computer Use needs a keyboard backend. Niri exports no
  # org.gnome.Mutter.RemoteDesktop, so the RemoteDesktop portal always refuses
  # CreateSession and /dev/uinput alone only gives the backend a pointer.
  # The module exports YDOTOOL_SOCKET, which the backend reads.
  programs.ydotool.enable = true;
  users.users.${userName}.extraGroups = [ "ydotool" ];

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
