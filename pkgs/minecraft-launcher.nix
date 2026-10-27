{ pkgs, ... }:

let
  # Mojang's bootstrap; it downloads the real launcher, Java runtime and game
  # into ~/.minecraft on first start, so this tarball rarely changes.
  src = pkgs.fetchurl {
    url = "https://launcher.mojang.com/download/Minecraft.tar.gz";
    hash = "sha256-aVJpKBVHu7z0f+dGMwJ6Dk3cE6YQYMaGpyF+hdMU5F4=";
  };

  launcher = pkgs.runCommand "minecraft-launcher-bin" { } ''
    mkdir -p "$out"
    tar -xzf ${src} --strip-components=1 -C "$out"
  '';

in
# The bootstrap, the CEF launcher UI, Mojang's JRE and LWJGL are all
# unpatched binaries fetched at runtime, so they need an FHS root rather
# than patchelf.
pkgs.buildFHSEnv {
  name = "minecraft-launcher";
  targetPkgs =
    p: with p; [
      # launcher UI (CEF / GTK)
      glib
      gtk3
      pango
      cairo
      atk
      at-spi2-atk
      at-spi2-core
      gdk-pixbuf
      cups
      nspr
      nss
      dbus
      expat
      libsecret
      libuuid
      libnotify
      libgbm
      libdrm
      libxkbcommon
      libx11
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxrandr
      libxrender
      libxtst
      libxscrnsaver
      libxcb
      libxshmfence
      libxxf86vm
      # game (JRE, LWJGL, OpenAL, narrator)
      zlib
      fontconfig
      freetype
      alsa-lib
      libpulseaudio
      pipewire
      openal
      flite
      udev
      libglvnd
      mesa
      vulkan-loader
      wayland
      curl
      openssl
    ];
  runScript = "${launcher}/minecraft-launcher";
  meta = {
    description = "Official Minecraft launcher from Mojang";
    platforms = [ "x86_64-linux" ];
    mainProgram = "minecraft-launcher";
  };
}
