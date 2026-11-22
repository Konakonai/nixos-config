{
  lib,
  pkgs,
  hostProfile,
  ...
}:

let
  askPass = lib.getExe' pkgs.kdePackages.ksshaskpass "ksshaskpass";
  userName = hostProfile.user.userName;
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
