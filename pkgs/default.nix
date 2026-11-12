{
  pkgs,
  inputs,
  lib ? pkgs.lib,
}:

{
  agy = pkgs.callPackage ./agy.nix { };
  antigravity = pkgs.callPackage ./antigravity.nix { };
  brave-origin = pkgs.callPackage ./brave-origin.nix { };
  celluloid-gl = pkgs.celluloid.overrideAttrs (previous: {
    preFixup = (previous.preFixup or "") + ''
      gappsWrapperArgs+=(--set GSK_RENDERER gl)
    '';
  });
  codex = pkgs.callPackage ./codex.nix { };
  codex-desktop = pkgs.callPackage ./codex-desktop.nix { inherit inputs; };
  genryumin = pkgs.callPackage ./genryumin.nix { };
  grok = pkgs.callPackage ./grok.nix { };
  grok-bot = pkgs.callPackage ./grok-bot.nix { };
  jetbrains-maple-mono = pkgs.callPackage ./jetbrains-maple-mono.nix { };
  # Shared by the NetworkManager hook (modules/system/programs.nix) and the
  # user timer (modules/home/desktop/kdeconnect.nix).
  kdeconnect-refresh = pkgs.writeShellApplication {
    name = "kdeconnect-refresh";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.kdePackages.kdeconnect-kde
    ];
    text = builtins.readFile ../scripts/kdeconnect-refresh.sh;
  };
  localsend-no-csd = pkgs.symlinkJoin {
    name = "${pkgs.localsend.name}-no-csd";
    paths = [ pkgs.localsend ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # niri does not draw server-side decorations, while KWin does. Keep the
    # Flutter CSD workaround scoped to niri so Plasma can provide its title bar.
    postBuild = ''
      rm "$out/bin/localsend_app"
      makeWrapper ${lib.getExe pkgs.localsend} "$out/bin/localsend_app" \
        --run 'case "''${XDG_CURRENT_DESKTOP:-}:''${XDG_SESSION_DESKTOP:-}" in *niri*) export GTK_CSD=0 ;; esac'
    '';
    meta = pkgs.localsend.meta;
  };
  magpie = pkgs.callPackage ./magpie.nix { };
  minecraft-launcher = pkgs.callPackage ./minecraft-launcher.nix { };
  touhou-grub-theme = pkgs.callPackage ./touhou-grub-theme.nix { };
  touhou-plymouth-theme = pkgs.callPackage ./touhou-plymouth-theme.nix { };
  wiiu-downloader = pkgs.callPackage ./wiiu-downloader.nix { };
}
