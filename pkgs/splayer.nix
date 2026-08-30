{ pkgs, ... }:

let
  pname = "splayer-next";
  version = "1.0.0";
  src = pkgs.fetchurl {
    url = "https://github.com/SPlayer-Dev/SPlayer-Next/releases/download/v${version}/splayer-next-${version}-x86_64.AppImage";
    hash = "sha256-11aQDxg76QtHG8cuRFGZRb5is1Ne5YercPXaI8la9Ug=";
  };
  appimageContents = pkgs.appimageTools.extractType2 { inherit pname version src; };
  desktopItem = pkgs.makeDesktopItem {
    name = "top.imsyy.splayer_next";
    desktopName = "SPlayer Next";
    exec = "splayer-next %U";
    icon = "SPlayer-Next";
    comment = "Cross-platform music player with rich lyric and audio format support";
    categories = [ "Audio" "Music" "AudioVideo" ];
    mimeTypes = [ "x-scheme-handler/orpheus" ];
    startupWMClass = "top.imsyy.splayer_next";
  };
in
pkgs.appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs = pkgs: with pkgs; [
    alsa-lib
    mpv
    udev
  ];

  extraInstallCommands = ''
    install -Dm444 ${desktopItem}/share/applications/top.imsyy.splayer_next.desktop -t $out/share/applications/
    cp -r ${appimageContents}/usr/share/icons $out/share/
  '';
}
