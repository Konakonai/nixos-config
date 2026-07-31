{ config, pkgs, ... }:

let
  gameStatus = pkgs.writeShellScriptBin "game-status" ''
    set -euo pipefail

    section() {
      printf '\n== %s ==\n' "$1"
    }

    section "GPU"
    if command -v nvidia-smi >/dev/null 2>&1; then
      nvidia-smi \
        --query-gpu=name,pstate,power.draw,memory.used,memory.total \
        --format=csv,noheader,nounits 2>/dev/null || true
      nvidia-smi \
        --query-compute-apps=pid,process_name,used_memory \
        --format=csv,noheader,nounits 2>/dev/null || true
    else
      echo "nvidia-smi not found"
    fi

    section "GameMode"
    if command -v gamemoded >/dev/null 2>&1; then
      gamemoded -s 2>/dev/null || true
    else
      echo "gamemoded not found"
    fi

    section "Focused window"
    if command -v niri >/dev/null 2>&1; then
      niri msg --json focused-window 2>/dev/null \
        | ${pkgs.jq}/bin/jq '{title, app_id, pid}' 2>/dev/null \
        || true
    else
      echo "niri not found"
    fi

    section "Controllers"
    for node in /dev/input/js*; do
      [ -e "$node" ] || continue
      name="$(cat "/sys/class/input/$(basename "$node")/device/name" 2>/dev/null || true)"
      printf '%s %s\n' "$node" "$name"
    done

    section "Vulkan"
    if [ -x ${pkgs.vulkan-tools}/bin/vulkaninfo ]; then
      ${pkgs.vulkan-tools}/bin/vulkaninfo --summary 2>/dev/null \
        | ${pkgs.gnugrep}/bin/grep -E 'GPU id|deviceName|apiVersion|driverName' \
        || true
    else
      echo "vulkaninfo not found"
    fi
  '';
in
{
  # This Bluetooth controller identifies as an Xbox pad but exposes a non-standard
  # HID button order. SDL applications need the machine-specific mapping below.
  home.sessionVariables.SDL_GAMECONTROLLERCONFIG =
    "050018dc491900000a0400001b010000,Xbox Wireless Controller,a:b0,b:b1,x:b2,y:b3,leftshoulder:b4,rightshoulder:b5,back:b6,start:b7,leftstick:b8,rightstick:b9,dpup:h0.1,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,leftx:a0,lefty:a1,rightx:a3,righty:a4,lefttrigger:a2,righttrigger:a5,platform:Linux,";

  home.packages = with pkgs; [
    cabextract
    cemu
    crosspipe
    dolphin-emu
    evtest
    gamescope
    gameStatus
    heroic
    linuxConsoleTools
    mangohud
    lilya.eden
    protonup-qt
    protontricks
    vulkan-tools
    wineWow64Packages.stableFull
    winetricks
    lilya.wiiu-downloader
  ];

  xdg.configFile."MangoHud/MangoHud.conf".text = ''
    legacy_layout=false
    horizontal
    fps
    frametime
    frame_timing
    gpu_name
    gpu_stats
    gpu_temp
    gpu_power
    cpu_stats
    ram
    vram
    gamemode
    wine
    engine_version
    vulkan_driver
    toggle_hud=Shift_R+F12
    toggle_logging=Shift_R+F11
    output_folder=${config.home.homeDirectory}/Games/MangoHud
  '';
}
