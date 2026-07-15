{ pkgs, lib, ... }:

let
  pname = "eden";
  version = "0.2.1";
  src = pkgs.fetchurl {
    url = "https://stable.eden-emu.dev/v${version}/Eden-Linux-v${version}-amd64-clang-pgo.AppImage";
    hash = "sha256-eii/mIsGSIMZiXIr26qQqzE3G0A4CBmYE+DqfIslum0=";
  };
  appimageContents = pkgs.appimageTools.extractType2 { inherit pname version src; };
in
pkgs.appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    if [ -d ${appimageContents}/usr/share/applications ]; then
      mkdir -p $out/share/applications
      cp -r ${appimageContents}/usr/share/applications/. $out/share/applications/
    fi
    if [ -d ${appimageContents}/usr/share/icons ]; then
      mkdir -p $out/share/icons
      cp -r ${appimageContents}/usr/share/icons/. $out/share/icons/
    fi
  '';

  meta = {
    description = "Nintendo Switch emulator";
    homepage = "https://eden-emu.dev/";
    license = lib.licenses.gpl3Only;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
