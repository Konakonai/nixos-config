{ lib, pkgs, ... }:

let
  askPass = lib.getExe' pkgs.kdePackages.ksshaskpass "ksshaskpass";
in
{
  programs.steam = {
    enable = true;
    package = pkgs.millennium-steam;
    extraPackages = with pkgs; [
      pulseaudio
    ];
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  programs.gamemode.enable = true;
  programs.kdeconnect.enable = true;
  programs.fish.enable = true;
  programs.nix-ld.enable = true;
  programs.ssh.askPassword = askPass;

  environment.systemPackages = [
    pkgs.kdePackages.ksshaskpass
  ];

  environment.variables.GIT_ASKPASS = askPass;
}
