{ pkgs, lib, ... }:

let
  pname = "qoder";
  version = "1.18.0-1784809365";

  src = pkgs.fetchurl {
    url = "https://download.qoder.com/release/1.18.0/qoder_amd64.deb";
    hash = "sha256-QAWpWI4TQKJm+a6hA2AOybYRSFzGYg2rgjk4Q7scylY=";
  };

  seedBundleCache = pkgs.writeShellApplication {
    name = "qoder-bundle-cache";
    runtimeInputs = [ pkgs.coreutils pkgs.util-linux ];
    text = builtins.readFile ../scripts/qoder-bundle-cache.sh;
  };

  runtimeLibs = with pkgs; [
    alsa-lib
    atk
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libglvnd
    libnotify
    libsecret
    libxkbcommon
    libxkbfile
    mesa
    nspr
    nss
    pango
    systemd
    vulkan-loader
    wayland
    libice
    libsm
    libx11
    libxscrnsaver
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxtst
    libxcb
    libxshmfence
  ];
in
pkgs.stdenvNoCC.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    dpkg
    gnutar
    makeShellWrapper
    wrapGAppsHook3
  ];

  buildInputs = runtimeLibs;

  dontBuild = true;
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile "$src" | tar --no-same-owner --no-same-permissions -xf -
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share"
    cp -r usr/share/qoder "$out/share/qoder"

    # Files copied from the immutable Nix store keep read-only modes. Qoder
    # writes a generated manifest at each bundled plugin's root after copying.
    substituteInPlace "$out/share/qoder/resources/app/out/main.js" \
      --replace-fail \
        'Wi.cpSync(o.sourceDir,a,{recursive:!0,filter:l=>Oe.basename(l)!==".DS_Store"}),HT(a,o.name)' \
        'Wi.cpSync(o.sourceDir,a,{recursive:!0,filter:l=>Oe.basename(l)!==".DS_Store"}),Wi.chmodSync(a,493),HT(a,o.name)'

    install -Dm444 usr/share/applications/qoder.desktop \
      "$out/share/applications/qoder.desktop"
    install -Dm444 usr/share/applications/qoder-url-handler.desktop \
      "$out/share/applications/qoder-url-handler.desktop"
    install -Dm444 usr/share/appdata/qoder.appdata.xml \
      "$out/share/appdata/qoder.appdata.xml"
    install -Dm444 usr/share/pixmaps/Qoder.png \
      "$out/share/pixmaps/Qoder.png"

    substituteInPlace "$out/share/applications/qoder.desktop" \
      --replace-fail "/usr/share/qoder/qoder" "$out/bin/qoder"
    substituteInPlace "$out/share/applications/qoder-url-handler.desktop" \
      --replace-fail "/usr/share/qoder/qoder" "$out/bin/qoder"

    makeShellWrapper "$out/share/qoder/qoder" "$out/bin/qoder" \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : "${lib.makeBinPath [ pkgs.bubblewrap ]}" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}" \
      --set-default ELECTRON_OZONE_PLATFORM_HINT auto \
      --set-default NIXOS_OZONE_WL 1 \
      --run '${lib.getExe seedBundleCache} "${placeholder "out"}/share/qoder/resources/app/resources/plugins/bundle-plugins" "$HOME/.qoder/plugins/cache/qoder-bundler" || exit $?' \
      --add-flags "--no-sandbox"

    runHook postInstall
  '';

  meta = {
    description = "Qoder Desktop - Agentic Coding Platform for Real Software";
    homepage = "https://qoder.com/desktop";
    license = lib.licenses.unfree;
    mainProgram = "qoder";
    platforms = [ "x86_64-linux" ];
  };
}
