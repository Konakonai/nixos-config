{ lib, appimageTools, fetchurl }:

let
  pname = "grok-bot";
  version = "0.47.0";
  src = fetchurl {
    url = "https://downloads.cursor.com/grokbot/stable/c1e7d7a46549956d25f53e9c0b9f59666e03aa3a/linux/x64/Grok_Bot_${version}.AppImage";
    hash = "sha256-wIL9qSgMQBtHy7/gEveytc79jZbBKR+A7shWGtbbSvM=";
  };
  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs = pkgs: with pkgs; [
    libsecret
    libnotify
  ];

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/grok-bot.desktop -t $out/share/applications/
    substituteInPlace $out/share/applications/grok-bot.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=grok-bot %U'
    cp -r ${appimageContents}/usr/share/icons $out/share/
  '';

  meta = with lib; {
    description = "Grok Bot desktop agent";
    homepage = "https://x.ai/bot";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "grok-bot";
  };
}
