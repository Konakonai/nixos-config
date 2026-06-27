{ pkgs, ... }:

let
  pname = "splayer";
  version = "3.1.1";
  src = pkgs.fetchurl {
    url = "https://github.com/SPlayer-Dev/SPlayer/releases/download/v3.1.1/splayer-3.1.1-x86_64.AppImage";
    sha256 = "0krcl9gfxmg8m15gn1qwqr2f2i6mwrzrd8izvrqw06zbm1m74zz4";
  };
  appimageContents = pkgs.appimageTools.extractType2 { inherit pname version src; };
  patchedAppimageContents = pkgs.runCommand "${pname}-${version}-patched" {
    nativeBuildInputs = [ pkgs.perl ];
  } ''
    cp -a ${appimageContents} $out
    chmod -R u+w $out

    # SPlayer's FFmpeg engine is WASM-based and requires SharedArrayBuffer.
    # The app already injects COOP/COEP headers, but webSecurity=false keeps
    # Electron from entering a cross-origin isolated renderer.
    perl -0pi -e 's/webSecurity: false/webSecurity: true /g' $out/resources/app.asar
    if grep -a -q "webSecurity: false" $out/resources/app.asar; then
      echo "failed to patch SPlayer webSecurity setting" >&2
      exit 1
    fi
  '';
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
pkgs.appimageTools.wrapAppImage {
  inherit pname version;
  src = patchedAppimageContents;

  extraPkgs = pkgs: with pkgs; [
    alsa-lib
    ffmpeg-full
    mpv
    udev
  ];

  extraInstallCommands = ''
    install -Dm444 ${desktopItem}/share/applications/SPlayer.desktop -t $out/share/applications/
    cp -r ${appimageContents}/usr/share/icons $out/share/
  '';
}
