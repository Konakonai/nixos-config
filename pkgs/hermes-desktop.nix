{ pkgs, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  electron43 = import ./electron-43-bin.nix { inherit pkgs; };
  hermes = inputs.hermes-agent.packages.${system}.default;
  hermesDesktopBase = inputs.hermes-agent.packages.${system}.desktop;
in
pkgs.runCommand "${hermesDesktopBase.name}-wayland-rendering" {
  nativeBuildInputs = [ pkgs.makeWrapper ];
  meta = hermesDesktopBase.meta or { };
} ''
    mkdir -p "$out/bin"
    cp -r ${hermesDesktopBase}/share "$out/share"
    grep -rl --fixed-strings ${hermesDesktopBase} "$out/share/hermes-desktop" | while read -r file; do
      substituteInPlace "$file" \
        --replace-fail ${hermesDesktopBase} "$out"
    done

    # Hermes Desktop/Electron on niri/NVIDIA Wayland can flash black blocks via the
    # GPU memory buffer/overlay path. Full SwiftShader keeps the window from
    # appearing, so use narrower compositor buffer flags here.
    makeWrapper "${electron43}/bin/electron" "$out/bin/hermes-desktop" \
      --set HERMES_DESKTOP_HERMES "${hermes}/bin/hermes" \
      --set ELECTRON_IS_DEV 0 \
      --add-flags "--disable-gpu-memory-buffer-compositor-resources" \
      --add-flags "--disable-native-gpu-memory-buffers" \
      --add-flags "--disable-features=WaylandOverlayDelegation" \
      --add-flags "$out/share/hermes-desktop"

    if [ -e "$out/share/applications/hermes-desktop.desktop" ]; then
      substituteInPlace "$out/share/applications/hermes-desktop.desktop" \
        --replace-fail "${hermesDesktopBase}/bin/hermes-desktop" "$out/bin/hermes-desktop"
    fi
''
