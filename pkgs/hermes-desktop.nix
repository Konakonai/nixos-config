{ pkgs, lib, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  hermes = inputs.hermes-agent.packages.${system}.default;
  hermesDesktopBase = inputs.hermes-agent.packages.${system}.desktop;
in
pkgs.symlinkJoin {
  name = "${hermesDesktopBase.name}-wayland-rendering";
  paths = [ hermesDesktopBase ];
  nativeBuildInputs = [ pkgs.makeWrapper ];

  postBuild = ''
    base_bin=${lib.escapeShellArg "${hermesDesktopBase}/bin/hermes-desktop"}
    electron="$(${pkgs.gnused}/bin/sed -n 's|^exec "\([^"]*\)".*|\1|p' "$base_bin" | ${pkgs.coreutils}/bin/head -n1)"
    if [ -z "$electron" ]; then
      echo "failed to locate Electron launcher in $base_bin" >&2
      exit 1
    fi

    # Hermes Desktop/Electron on niri/NVIDIA Wayland can flash black blocks via the
    # GPU memory buffer/overlay path. Full SwiftShader keeps the window from
    # appearing, so use narrower compositor buffer flags here.
    rm -f "$out/bin/hermes-desktop"
    makeWrapper "$electron" "$out/bin/hermes-desktop" \
      --set HERMES_DESKTOP_HERMES "${hermes}/bin/hermes" \
      --set ELECTRON_IS_DEV 0 \
      --add-flags "--disable-gpu-memory-buffer-compositor-resources" \
      --add-flags "--disable-native-gpu-memory-buffers" \
      --add-flags "--disable-features=WaylandOverlayDelegation" \
      --add-flags "${hermesDesktopBase}/share/hermes-desktop"

    if [ -e "$out/share/applications/hermes-desktop.desktop" ]; then
      substituteInPlace "$out/share/applications/hermes-desktop.desktop" \
        --replace-fail "${hermesDesktopBase}/bin/hermes-desktop" "$out/bin/hermes-desktop"
    fi
  '';

  meta = hermesDesktopBase.meta or { };
}
