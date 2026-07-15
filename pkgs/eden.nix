{ pkgs, lib, ... }:

let
  pname = "eden";
  version = "0.2.1";
  src = pkgs.fetchurl {
    url = "https://stable.eden-emu.dev/v${version}/Eden-Linux-v${version}-amd64-clang-pgo.AppImage";
    hash = "sha256-eii/mIsGSIMZiXIr26qQqzE3G0A4CBmYE+DqfIslum0=";
  };
  appimageContents = pkgs.runCommand "${pname}-${version}-extracted"
    {
      nativeBuildInputs = [ pkgs.dwarfs ];
    }
    ''
      mkdir -p $out
      dwarfsextract -i ${src} -o $out
    '';
in
pkgs.appimageTools.wrapAppImage {
  inherit pname version;
  src = appimageContents;

  # Eden ships a wayland-is-broken hook that otherwise forces Qt onto XWayland.
  # The AppImage includes its Qt Wayland platform and EGL integration plugins.
  profile = ''
    export I_WANT_A_BROKEN_WAYLAND_UI=1
  '';

  extraInstallCommands = ''
    install -Dm444 \
      ${appimageContents}/dev.eden_emu.eden.desktop \
      $out/share/applications/dev.eden_emu.eden.desktop
    install -Dm444 \
      ${appimageContents}/dev.eden_emu.eden.svg \
      $out/share/icons/hicolor/scalable/apps/dev.eden_emu.eden.svg
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
