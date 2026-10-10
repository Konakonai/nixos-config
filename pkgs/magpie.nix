{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  wrapGAppsHook3,
  gtk3,
  webkitgtk_4_1,
  glib-networking,
  makeDesktopItem,
  copyDesktopItems,
}:

let
  pname = "magpie";
  version = "0.1.1157";

  src = fetchurl {
    url = "https://github.com/yetone/magpie-releases/releases/download/v${version}/magpie-linux-amd64";
    hash = "sha256-NoRkaVgCk5nP6T0Z/zW3MjXRamLPtZWMrESfTpEu5ek=";
  };

  icon = fetchurl {
    url = "https://raw.githubusercontent.com/yetone/magpie/v${version}/site/public/img/icon-256.png";
    hash = "sha256-V0N8ZZbgWo/PxC1CiMAwqgDthraf411GTWnXAmFQxwQ=";
  };
in
stdenv.mkDerivation {
  inherit pname version src;

  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook3
    copyDesktopItems
  ];

  buildInputs = [
    gtk3
    webkitgtk_4_1
    glib-networking
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "magpie";
      desktopName = "Magpie";
      genericName = "AI Model Manager";
      comment = "Centralized AI model manager and gateway for coding agents";
      exec = "magpie %u";
      icon = "magpie";
      categories = [
        "Development"
        "Utility"
      ];
      mimeTypes = [ "x-scheme-handler/magpie" ];
      terminal = false;
    })
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/magpie"
    install -Dm644 "${icon}" "$out/share/icons/hicolor/256x256/apps/magpie.png"

    runHook postInstall
  '';

  meta = {
    description = "Centralized AI model manager and gateway for coding agents";
    homepage = "https://usemagpie.ai";
    downloadPage = "https://github.com/yetone/magpie-releases";
    license = lib.licenses.mit;
    mainProgram = "magpie";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
