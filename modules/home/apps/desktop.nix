{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs.lilya)
    agy
    antigravity
    grok-bot
    localsend-no-csd
    magpie
    wlroots-bridge
    ;
  # Computer Use on niri drives whatever Wayland display wlroots-bridge
  # connects to, through virtual-pointer/keyboard rather than the real seat.
  # Pointing it at a headless sway lets Claude click and type there without
  # moving the user's cursor or focus. The bridge inherits the app's
  # environment, so this wrapper swaps WAYLAND_DISPLAY while claude-cu-desk is
  # running and falls back to the main session otherwise.
  #
  # The executor takes monitor geometry from Electron (the real outputs) and
  # caches the bridge's output names for the life of the app, so the headless
  # outputs mirror each real output's position and scale, and --display is
  # translated between real and HEADLESS-n names in whichever direction the
  # current target needs. The bundled bridge loses input on sway, so the
  # wrapper runs a patched build from source instead (see pkgs/wlroots-bridge.nix).
  cuState = ''"$XDG_RUNTIME_DIR/claude-cu"'';
  cuBridge = pkgs.writeShellScript "claude-cu-bridge" ''
    state=${cuState}
    redirect=0
    if [ -r "$state/env" ]; then
      . "$state/env"
      if [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
        export WAYLAND_DISPLAY
        redirect=1
      fi
    fi
    args=()
    while [ $# -gt 0 ]; do
      if [ "$1" = --display ] && [ $# -ge 2 ] && [ -r "$state/outputs" ]; then
        name=$2
        while read -r real headless; do
          if [ $redirect = 1 ] && [ "$name" = "$real" ]; then name=$headless; fi
          if [ $redirect = 0 ] && [ "$name" = "$headless" ]; then name=$real; fi
        done < "$state/outputs"
        args+=(--display "$name")
        shift 2
        continue
      fi
      args+=("$1")
      shift
    done
    exec "$CLAUDE_CU_REAL_BRIDGE" "''${args[@]}"
  '';
  claude-cu-desk = pkgs.writeShellApplication {
    name = "claude-cu-desk";
    runtimeInputs = [
      config.programs.niri.package
      pkgs.jq
      pkgs.sway
    ];
    text = ''
      state=${cuState}
      mkdir -p "$state"
      if [ "''${1-}" = stop ]; then
        [ -r "$state/pid" ] && kill "$(cat "$state/pid")"
        exit 0
      fi

      outputs=$(niri msg -j outputs | jq -c '
        [to_entries[] | select(.value.logical != null)] | sort_by(.key) | to_entries[]
        | {real: .value.key, headless: "HEADLESS-\(.key + 1)", l: .value.value.logical,
           mode: .value.value.modes[.value.value.current_mode]}')
      : > "$state/outputs"
      config="$state/sway.conf"
      {
        echo "default_border none"
        echo "focus_follows_mouse no"
        while read -r o; do
          jq -r '"\(.real) \(.headless)"' <<<"$o" >> "$state/outputs"
          jq -r '"output \(.headless) mode \(.mode.width)x\(.mode.height) position \(.l.x) \(.l.y) scale \(.l.scale) bg #303030 solid_color"' <<<"$o"
        done <<<"$outputs"
        # shellcheck disable=SC2016
        printf '%s\n' "exec sh -c 'printf \"WAYLAND_DISPLAY=%s\\nDISPLAY=%s\\n\" \"\$WAYLAND_DISPLAY\" \"\''${DISPLAY-}\" > $state/env.tmp && mv $state/env.tmp $state/env'"
      } > "$config"

      trap 'rm -f "$state/env" "$state/pid"' EXIT
      # Headless, so it keeps rendering with no window on the real desktop;
      # pixman, so it never touches the dGPU (which must stay asleep on battery).
      env -u WAYLAND_DISPLAY -u DISPLAY -u NIRI_SOCKET \
        WLR_BACKENDS=headless \
        WLR_HEADLESS_OUTPUTS="$(wc -l < "$state/outputs")" \
        WLR_RENDERER=pixman \
        WLR_LIBINPUT_NO_DEVICES=1 \
        sway -c "$config" &
      echo $! > "$state/pid"
      wait
    '';
  };
  # open_application launches with the app's own environment and so lands on
  # the main desktop; start programs for the headless display through this.
  claude-cu-run = pkgs.writeShellApplication {
    name = "claude-cu-run";
    text = ''
      env=${cuState}/env
      if [ ! -r "$env" ]; then
        echo "claude-cu-run: claude-cu-desk is not running" >&2
        exit 1
      fi
      set -a
      # shellcheck disable=SC1090
      . "$env"
      set +a
      exec "$@"
    '';
  };
  claude-desktop =
    (inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop.override {
      # Upstream v2.2553.x is built against Electron 44; nixpkgs' default
      # `electron` alias lags behind, so pin the major the bundle expects.
      electron = pkgs.electron_44;
    }).overrideAttrs
      (oldAttrs: {
        postFixup = (oldAttrs.postFixup or "") + ''
          wrapProgram $out/bin/claude-desktop \
            --set CHROME_DEVEL_SANDBOX "$out/lib/claude-desktop/chrome-sandbox" \
            --set WLROOTS_BRIDGE_BIN ${cuBridge} \
            --set CLAUDE_CU_REAL_BRIDGE ${lib.getExe wlroots-bridge}

          # The bundled node-pty binding links libstdc++, but Electron itself
          # ships a static libc++, so nothing in the process provides it and
          # the pty-host worker dies with a misleading "Cannot find module
          # pty.node" (the built-in terminal shows "Failed to spawn shell").
          # Give the binding its own RPATH instead of leaking LD_LIBRARY_PATH
          # into every shell and MCP server the app spawns.
          pty=$out/lib/claude-desktop/resources/app.asar.unpacked/node_modules/node-pty/prebuilds/linux-x64/pty.node
          chmod u+w "$pty"
          patchelf --add-rpath ${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]} "$pty"
        '';
      });
  # 2.0.0 registers the NativeShell user script on the view, and the
  # cross-origin hop from the bundled server picker to the server's web client
  # moves the view to a new renderer that never gets it. jellyfin-web then
  # reports itself as a plain browser and the server transcodes everything
  # (mkv, HEVC, DTS) for the HTML player instead of handing it to mpv.
  # Upstream fixed it after 2.0.0 by registering on the profile; drop this
  # once a release includes jellyfin/jellyfin-desktop#1236.
  jellyfin-desktop = pkgs.jellyfin-desktop.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      (pkgs.fetchpatch {
        url = "https://github.com/jellyfin/jellyfin-desktop/commit/cabddc60908283b78f523a709b8a3a295d2b9fab.patch";
        hash = "sha256-3EKSfiDqwPZp2x8durPq7UWgq9jHaAWAoXe9wpHlhp0=";
      })
    ];
  });
  fontMimeTypes = [
    "application/vnd.ms-opentype"
    "application/x-font-otf"
    "application/x-font-pcf"
    "application/x-font-ttf"
    "application/x-font-type1"
    "font/collection"
    "font/otf"
    "font/ttf"
    "font/woff"
    "font/woff2"
  ];
  imageMimeTypes = [
    "image/apng"
    "image/avif"
    "image/bmp"
    "image/gif"
    "image/heic"
    "image/jpeg"
    "image/jp2"
    "image/jxl"
    "image/png"
    "image/svg+xml"
    "image/svg+xml-compressed"
    "image/tiff"
    "image/vnd.microsoft.icon"
    "image/webp"
    "image/x-dds"
    "image/x-exr"
    "image/x-portable-anymap"
    "image/x-portable-bitmap"
    "image/x-portable-graymap"
    "image/x-portable-pixmap"
    "image/x-qoi"
    "image/x-tga"
    "image/x-win-bitmap"
    "image/x-xbitmap"
    "image/x-xpixmap"
  ];
in
{
  home.packages = with pkgs; [
    agy
    antigravity
    claude-cu-desk
    claude-cu-run
    claude-desktop
    file-roller
    foliate
    gimp
    gnome-font-viewer
    grok-bot
    hyprpicker
    jellyfin-desktop
    kdePackages.okular
    localsend-no-csd
    loupe
    magpie
    mcomix
    nemo-with-extensions
    obsidian
    pavucontrol
    resources
    splayer-next
    thunderbird
  ];

  # Magpie registers its unwrapped store executable in a user desktop file,
  # which shadows the packaged launcher and stays on an old version after updates.
  # Manage the user entry too, so Magpie cannot replace the wrapped launcher.
  xdg.dataFile."applications/magpie.desktop" = {
    source = "${magpie}/share/applications/magpie.desktop";
    force = true;
  };

  # Magpie's "launch at login" writes the same kind of pinned path into its
  # autostart entry, so every login brought back the tray of whatever version
  # was installed when the toggle was flipped, and later launches only focused
  # that instance. Own the entry and point it at the wrapped launcher. If Home
  # Manager ever moves a replaced entry aside, delete the .backup copy:
  # systemd's xdg-autostart generator still starts it.
  xdg.configFile."autostart/magpie.desktop" = {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Magpie
      Exec=${lib.getExe magpie} tray
      Icon=magpie
      Terminal=false
      X-GNOME-Autostart-enabled=true
    '';
    force = true;
  };

  xdg.desktopEntries = {
    # The system vim package ships upstream launcher entries. vim is only used
    # from a shell, and gvim.desktop points at a GUI this build does not have.
    vim = {
      name = "Vim";
      exec = "vim %F";
      terminal = true;
      noDisplay = true;
    };
    gvim = {
      name = "GVim";
      exec = "gvim -f %F";
      noDisplay = true;
    };

    antigravity = {
      name = "Antigravity";
      exec = "${lib.getExe antigravity} %F";
      icon = "antigravity";
      type = "Application";
      categories = [ "Utility" ];
      terminal = false;
      mimeType = [ "x-scheme-handler/antigravity" ];
    };

    nemo = {
      name = "Files";
      genericName = "File Manager";
      exec = "${pkgs.nemo-with-extensions}/bin/nemo %U";
      icon = "system-file-manager";
      terminal = false;
      categories = [
        "Utility"
        "FileTools"
        "System"
        "FileManager"
      ];
      mimeType = [ "inode/directory" ];
    };

    "org.gnome.Loupe" = {
      name = "Image Viewer";
      genericName = "Image Viewer";
      exec = "${lib.getExe pkgs.loupe} %U";
      icon = "org.gnome.Loupe";
      terminal = false;
      categories = [
        "GNOME"
        "GTK"
        "Graphics"
        "2DGraphics"
        "RasterGraphics"
        "Viewer"
      ];
      mimeType = imageMimeTypes;
      startupNotify = true;
      settings.DBusActivatable = "false";
    };

    "org.gnome.font-viewer" = {
      name = "Fonts";
      genericName = "Font Viewer";
      exec = "${lib.getExe' pkgs.gnome-font-viewer "gnome-font-viewer"} %u";
      icon = "org.gnome.font-viewer";
      terminal = false;
      categories = [
        "GNOME"
        "GTK"
        "Utility"
      ];
      mimeType = fontMimeTypes;
      startupNotify = true;
      settings.DBusActivatable = "false";
    };
  };
}
