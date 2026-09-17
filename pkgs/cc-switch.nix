{ pkgs, lib, ... }:

let
  pname = "cc-switch";
  version = "3.20.3";
  src = pkgs.fetchurl {
    url = "https://github.com/farion1231/cc-switch/releases/download/v${version}/CC-Switch-v${version}-Linux-x86_64.AppImage";
    hash = "sha256-IGva0ItirS/bV+UurOIie6gvQPX7dDq5k0KRruaTWPM=";
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
