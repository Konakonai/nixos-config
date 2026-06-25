{ config, pkgs, ... }:

let
  clipboardScreenshot = pkgs.writeShellScriptBin "clipboard-screenshot" ''
    set -euo pipefail

    unset LD_LIBRARY_PATH

    geometry="$(${pkgs.slurp}/bin/slurp -o -r -c '#f5c2e7ff')" || exit 0
    [ -n "$geometry" ] || exit 0

    ${pkgs.grim}/bin/grim -g "$geometry" - \
      | ${pkgs.wl-clipboard}/bin/wl-copy --type image/png
  '';

  sattyScreenshot = pkgs.writeShellScriptBin "satty-screenshot" ''
    set -euo pipefail

    unset LD_LIBRARY_PATH

    mode="''${1:-area}"
    screenshot_dir="$HOME/Pictures/Screenshots"
    ${pkgs.coreutils}/bin/mkdir -p "$screenshot_dir"

    output="$screenshot_dir/screenshot-$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S).png"
    tmp_dir="''${XDG_RUNTIME_DIR:-/tmp}"
    tmp="$(${pkgs.coreutils}/bin/mktemp --tmpdir="$tmp_dir" satty-screenshot.XXXXXX.png)"

    cleanup() {
      ${pkgs.coreutils}/bin/rm -f "$tmp"
    }
    trap cleanup EXIT

    run_satty() {
      ${pkgs.satty}/bin/satty \
        --filename "$1" \
        --fullscreen current-screen \
        --floating-hack \
        --no-window-decoration \
        --early-exit \
        --copy-command "${pkgs.wl-clipboard}/bin/wl-copy" \
        --output-filename "$output" \
        --actions-on-enter "save-to-clipboard,exit" \
        --actions-on-right-click "save-to-clipboard,exit" \
        --actions-on-escape "exit" \
        --initial-tool arrow \
        --brush-smooth-history-size 5 \
        --disable-notifications
    }

    case "$mode" in
      area)
        geometry="$(${pkgs.slurp}/bin/slurp -o -r -c '#f5c2e7ff')" || exit 0
        [ -n "$geometry" ] || exit 0
        ${pkgs.grim}/bin/grim -t ppm -g "$geometry" - | run_satty -
        ;;
      screen)
        ${config.programs.niri.package}/bin/niri msg action screenshot-screen --path "$tmp"
        [ -s "$tmp" ] || exit 1
        run_satty "$tmp"
        ;;
      window)
        ${config.programs.niri.package}/bin/niri msg action screenshot-window --path "$tmp"
        [ -s "$tmp" ] || exit 1
        run_satty "$tmp"
        ;;
      *)
        echo "usage: satty-screenshot [area|screen|window]" >&2
        exit 2
        ;;
    esac
  '';
in
{
  home.packages = [
    clipboardScreenshot
    sattyScreenshot
  ];

  programs.niri.settings.binds = with config.lib.niri.actions; {
    "Mod+R".action.switch-preset-column-width = [];
    "Mod+Shift+R".action.switch-preset-column-width-back = [];
    "Mod+Ctrl+Shift+R".action.switch-preset-window-height = [];
    "Mod+Ctrl+R".action.reset-window-height = [];
    "Mod+Minus".action.set-column-width = [ "-10%" ];
    "Mod+Equal".action.set-column-width = [ "+10%" ];
    "Mod+Shift+Minus".action.set-window-height = [ "-10%" ];
    "Mod+Shift+Equal".action.set-window-height = [ "+10%" ];

    "Mod+Shift+S".action.spawn = [ "clipboard-screenshot" ];
    "Mod+Ctrl+Shift+S".action.spawn = [ "satty-screenshot" "area" ];
    "Print".action.screenshot = [];
    "Ctrl+Print".action.screenshot-screen = { write-to-disk = false; };
    "Alt+Print".action.screenshot-window = { write-to-disk = false; };

    "Mod+Escape".action.spawn = [ "noctalia" "msg" "session" "lock" ];
    "Mod+M".action.spawn = [ "noctalia" "msg" "panel-toggle" "session" ];
    "Mod+N".action.spawn = [ "noctalia" "msg" "panel-toggle" "control-center" "notifications" ];
    "Mod+X".action.spawn = [ "noctalia" "msg" "panel-toggle" "control-center" ];
    "Mod+Shift+C".action.spawn = [ "noctalia" "msg" "panel-toggle" "clipboard" ];

    "XF86AudioRaiseVolume".action.spawn = [ "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+" ];
    "XF86AudioLowerVolume".action.spawn = [ "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-" ];
    "XF86AudioMute".action.spawn = [ "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle" ];

    "XF86MonBrightnessUp".action.spawn = [ "brightnessctl" "set" "+5%" ];
    "XF86MonBrightnessDown".action.spawn = [ "brightnessctl" "set" "5%-" ];

    "Mod+Shift+E".action.quit = [];
    "Mod+Shift+P".action.power-off-monitors = [];
  };
}
