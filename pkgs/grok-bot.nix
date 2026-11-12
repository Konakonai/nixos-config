{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "grok-bot";
  # The commit in the URL comes from the update feed, which answers with the
  # latest release (HTTP 204 when already current); update-pins rewrites it:
  #   curl -fsSL https://api2.cursor.sh/updates/api/update/linux-x64/sand/<version>/<commit>/stable
  version = "1.0.1";
  commit = "7eb488cd12ea2e65065a6b227f3ab49160b618bd";
  src = fetchurl {
    url = "https://downloads.cursor.com/grokbot/stable/${commit}/linux/x64/Grok_Bot_${version}.AppImage";
    hash = "sha256-rlLK6iUomHp7qiSf8qWsjiECyeXDvubtMI+Xe5GoMtI=";
  };
  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs =
    pkgs: with pkgs; [
      libsecret
      libnotify
    ];

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/grok-bot.desktop -t $out/share/applications/
    substituteInPlace $out/share/applications/grok-bot.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox -- %U' 'Exec=grok-bot -- %U'
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
