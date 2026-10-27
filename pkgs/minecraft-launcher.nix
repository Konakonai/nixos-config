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
  # The game's SDL falls back to XWayland when the compositor lacks fifo-v1
  # (niri does), and NVIDIA Vulkan through xwayland-satellite tears even with
  # VSync on. Force native Wayland, which presents through niri properly.
  profile = ''
    export SDL_VIDEO_DRIVER=wayland
    # On native Wayland, EGL follows the compositor onto the iGPU even though
    # the game asks for the discrete one; PRIME offload pins both OpenGL and
    # Vulkan to the RTX 4060.
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/10_nvidia.json
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
  '';
  runScript = "${launcher}/minecraft-launcher";
  meta = {
    description = "Official Minecraft launcher from Mojang";
    platforms = [ "x86_64-linux" ];
    mainProgram = "minecraft-launcher";
  };
}
