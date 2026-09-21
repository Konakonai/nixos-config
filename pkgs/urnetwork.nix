{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "urnetwork";
  version = "2026.9.19-1050096260";
  src = fetchurl {
    url = "https://github.com/urnetwork/build/releases/download/v${version}/URnetwork-${version}-amd64.AppImage";
    hash = "sha256-tS0uO6eoK5zFihirj7dWyb99kkhzSJAwIX4zcwy4pdI=";
  };
  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs =
    pkgs: with pkgs; [
      libnotify
      libsecret
      openssl
    ];

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/com.bringyour.network.desktop $out/share/applications/com.bringyour.network.desktop
    substituteInPlace $out/share/applications/com.bringyour.network.desktop \
      --replace-fail 'Exec=urnetwork-gui %u' 'Exec=urnetwork %u' \
      --replace-fail 'TryExec=urnetwork-gui' 'TryExec=urnetwork'
    install -Dm444 ${appimageContents}/com.bringyour.network.png $out/share/pixmaps/com.bringyour.network.png
    cp -r ${appimageContents}/usr/share/icons $out/share/
    ln -s $out/bin/urnetwork $out/bin/urnetwork-gui
  '';

  meta = with lib; {
    description = "Decentralized VPN (dVPN) client by URnetwork";
    homepage = "https://ur.io";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "urnetwork";
  };
}
