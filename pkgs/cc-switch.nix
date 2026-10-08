{ pkgs, lib, ... }:

let
  pname = "cc-switch";
  version = "4.0.4";
  src = pkgs.fetchurl {
    url = "https://github.com/farion1231/cc-switch/releases/download/v${version}/CC-Switch-v${version}-Linux-x86_64.AppImage";
    hash = "sha256-O1OESV8e6jInR6M8ZKBFRCtdMB68xDSIvrEhJMof538=";
  };
  appimageContents = pkgs.appimageTools.extract { inherit pname version src; };
in
pkgs.appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs =
    pkgs: with pkgs; [
      glib-networking
      openssl
      webkitgtk_4_1
    ];

  profile = ''
    case "''${XDG_CURRENT_DESKTOP:-}" in
      *KDE*) export CC_SWITCH_GDK_BACKEND=wayland ;;
    esac
  '';

  extraInstallCommands = ''
    install -Dm444 "${appimageContents}/usr/share/applications/CC Switch.desktop" -t $out/share/applications/
    substituteInPlace "$out/share/applications/CC Switch.desktop" \
      --replace-fail 'Exec=cc-switch' 'Exec=cc-switch %u'
    cp -r ${appimageContents}/usr/share/icons $out/share/
  '';

  meta = {
    description = "All-in-one assistant for Claude Code, Codex, OpenCode, Gemini CLI and other AI coding agents";
    homepage = "https://ccswitch.io";
    downloadPage = "https://github.com/farion1231/cc-switch";
    license = lib.licenses.mit;
    mainProgram = "cc-switch";
    platforms = [ "x86_64-linux" ];
  };
}
