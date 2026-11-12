# Vendored from nixpkgs 0bb2eedc (pkgs/applications/networking/browsers/brave),
# trimmed to Brave Origin on x86_64-linux. nixpkgs dropped brave and
# brave-origin on 2026-11-03 because no committer was left to land security
# bumps, so keep this current via update-pins.
{
  lib,
  stdenv,
  fetchurl,
  buildPackages,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  dpkg,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  adwaita-icon-theme,
  gsettings-desktop-schemas,
  gtk3,
  gtk4,
  qt6,
  libx11,
  libxscrnsaver,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxtst,
  libdrm,
  libkrb5,
  libuuid,
  libxkbcommon,
  libxshmfence,
  libgbm,
  nspr,
  nss,
  pango,
  pciutils,
  pipewire,
  snappy,
  speechd-minimal,
  udev,
  wayland,
  widevine-cdm,
  xdg-utils,
  coreutils,
  libxcb,
  vulkan-loader,
  zlib,
  libpulseaudio,
  libGL,
  libva,
}:

let
  pname = "brave-origin";
  version = "1.99.57";
  optDir = "opt/brave.com/brave-origin";

  deps = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    gtk4
    libdrm
    libx11
    libGL # GPU acceleration on Wayland
    libxkbcommon
    libxscrnsaver
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxshmfence
    libxtst
    libuuid
    libgbm
    nspr
    nss
    pango
    pciutils # ANGLE dlopens libpci to identify GPUs, including for VA-API device selection.
    pipewire
    udev
    wayland
    libxcb
    zlib
    snappy
    speechd-minimal # Text-to-speech through speech-dispatcher.
    libkrb5
    vulkan-loader # Chromium and Dawn dlopen libvulkan.so.1 by name.
    qt6.qtbase
    libpulseaudio # USB audio devices
    libva # VA-API video acceleration
  ];

  rpath = lib.makeLibraryPath deps + ":" + lib.makeSearchPathOutput "lib" "lib64" deps;

  enableFeatures = [
    "AcceleratedVideoDecodeLinuxGL"
    "AcceleratedVideoEncoder"
  ];

  disableFeatures = [
    # Updates come through Nix.
    "OutdatedBuildDetector"
    # Needed for VA-API to work: https://github.com/brave/brave-browser/issues/20935
    "UseChromeOSDirectVideoDecoder"
  ];
in
stdenv.mkDerivation {
  inherit pname version;

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchurl {
    url = "https://github.com/brave/brave-browser/releases/download/v${version}/brave-origin_${version}_amd64.deb";
    hash = "sha256-TLGtTqDl+lK0/d1ZNi56nZQnZlf+FqYgPQwdJb2Pcw4=";
  };

  dontConfigure = true;
  dontBuild = true;
  dontPatchELF = true;
  doInstallCheck = true;

  nativeBuildInputs = [
    dpkg
    # override doesn't preserve splicing https://github.com/NixOS/nixpkgs/issues/132651
    (buildPackages.wrapGAppsHook3.override { makeWrapper = buildPackages.makeShellWrapper; })
  ];

  buildInputs = [
    # GSETTINGS_SCHEMAS_PATH
    glib
    gsettings-desktop-schemas
    gtk3
    gtk4
    # XDG_ICON_DIRS
    adwaita-icon-theme
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp -R usr/share $out
    cp -R opt/ $out/opt

    wrapper=$out/${optDir}/brave-origin
    substituteInPlace $wrapper \
      --replace-fail /bin/bash ${stdenv.shell} \
      --replace-fail 'CHROME_WRAPPER' 'WRAPPER'
    ln -sf $wrapper $out/bin/brave-origin

    for exe in $out/${optDir}/{brave,chrome_crashpad_handler}; do
      patchelf \
        --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
        --set-rpath "${rpath}" $exe
    done

    substituteInPlace $out/share/applications/{brave-origin,com.brave.Origin}.desktop \
      --replace-fail /usr/bin/brave-origin-stable $out/bin/brave-origin
    substituteInPlace $out/share/gnome-control-center/default-apps/brave-origin.xml \
      --replace-fail /opt/brave.com $out/opt/brave.com
    substituteInPlace $out/${optDir}/default-app-block \
      --replace-fail /opt/brave.com $out/opt/brave.com

    for size in 16 24 32 48 64 128 256; do
      mkdir -p $out/share/icons/hicolor/''${size}x''${size}/apps
      ln -s $out/${optDir}/product_logo_$size.png \
        $out/share/icons/hicolor/''${size}x''${size}/apps/brave-origin.png
    done

    # ANGLE loads this copy by absolute path; the NixOS-patched loader finds ICDs
    # under /run/opengl-driver, the bundled one does not.
    rm $out/${optDir}/libvulkan.so.1
    ln -s ${lib.getLib vulkan-loader}/lib/libvulkan.so.1 $out/${optDir}/libvulkan.so.1

    ln -sf ${xdg-utils}/bin/xdg-settings $out/${optDir}/xdg-settings
    ln -sf ${xdg-utils}/bin/xdg-mime $out/${optDir}/xdg-mime

    # The .deb ships without the Widevine CDM, so DRM streaming sites refuse
    # to play.
    ln -s ${widevine-cdm}/share/google/chrome/WidevineCdm $out/${optDir}/WidevineCdm

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${rpath}
      --prefix PATH : ${lib.makeBinPath deps}
      --suffix PATH : ${
        lib.makeBinPath [
          xdg-utils
          coreutils
        ]
      }
      --set CHROME_WRAPPER ${pname}
      --add-flags "--enable-features=${lib.concatStringsSep "," enableFeatures}\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+,WaylandWindowDecorations --enable-wayland-ime=true}}"
      --add-flags "--disable-features=${lib.concatStringsSep "," disableFeatures}"
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"
    )
  '';

  installCheckPhase = ''
    # Bypass upstream wrapper which suppresses errors
    $out/${optDir}/brave --version
  '';

  meta = {
    homepage = "https://brave.com/origin/";
    description = "Privacy-oriented browser for Desktop and Laptop computers (Origin variant)";
    changelog =
      "https://github.com/brave/brave-browser/blob/master/CHANGELOG_DESKTOP_ORIGIN.md#"
      + lib.replaceStrings [ "." ] [ "" ] version;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.mpl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "brave-origin";
  };
}
