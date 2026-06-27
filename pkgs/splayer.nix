{ pkgs, ... }:

let
  pname = "splayer";
  version = "3.1.1";
  src = pkgs.fetchurl {
    url = "https://github.com/SPlayer-Dev/SPlayer/releases/download/v3.1.1/splayer-3.1.1-x86_64.AppImage";
    sha256 = "0krcl9gfxmg8m15gn1qwqr2f2i6mwrzrd8izvrqw06zbm1m74zz4";
  };
  appimageContents = pkgs.appimageTools.extractType2 { inherit pname version src; };
  desktopItem = pkgs.makeDesktopItem {
    name = "SPlayer";
    desktopName = "SPlayer";
    exec = "splayer %U";
    icon = "SPlayer";
    comment = "A minimalist music player";
    categories = [ "Audio" "Music" "AudioVideo" ];
    mimeTypes = [ "x-scheme-handler/orpheus" ];
    startupWMClass = "SPlayer";
  };
in
pkgs.appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs = pkgs: with pkgs; [
    alsa-lib
    udev
  ];

  extraInstallCommands = ''
    install -Dm444 ${desktopItem}/share/applications/SPlayer.desktop -t $out/share/applications/
    cp -r ${appimageContents}/usr/share/icons $out/share/
  '';
}
