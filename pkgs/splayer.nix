{ pkgs, lib, ... }:

let
  pname = "splayer";
  version = "3.1.1";
  src = pkgs.fetchurl {
    url = "https://github.com/SPlayer-Dev/SPlayer/releases/download/v3.1.1/splayer-3.1.1-x86_64.AppImage";
    sha256 = "0krcl9gfxmg8m15gn1qwqr2f2i6mwrzrd8izvrqw06zbm1m74zz4";
  };
  appimageContents = pkgs.appimageTools.extractType2 { inherit pname version src; };
in
pkgs.appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs = pkgs: with pkgs; [
    alsa-lib
    udev
  ];

  extraInstallCommands = ''
    # Copy desktop item and icons
    install -Dm444 ${appimageContents}/SPlayer.desktop -t $out/share/applications/
    cp -r ${appimageContents}/usr/share/icons $out/share/

    # The upstream AppImage desktop file points at AppRun; the wrapped Nix
    # package should launch through the generated splayer wrapper instead.
    substituteInPlace $out/share/applications/SPlayer.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=splayer %U'
  '';
}
