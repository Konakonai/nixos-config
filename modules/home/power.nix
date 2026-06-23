{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "toggle-power-mode" ''
      STATUS_FILE="/sys/class/power_supply/BAT0/extensions/ideapad_laptop/conservation_mode"
      STATE_FILE="$HOME/.config/niri/power-mode-state"

      CURRENT_STATE="performance"
      if [ -f "$STATE_FILE" ]; then
        CURRENT_STATE=$(cat "$STATE_FILE")
      fi

      if [ "$CURRENT_STATE" = "performance" ]; then
        if [ -f "$STATUS_FILE" ]; then
          echo 0 > "$STATUS_FILE"
        fi

        if [ -e /sys/bus/pci/devices/0000:01:00.0 ]; then
          echo 1 > /sys/bus/pci/devices/0000:01:00.0/remove || true
        fi

        echo "powersave" > "$STATE_FILE"
        ${pkgs.libnotify}/bin/notify-send -i battery-caution "电源管理" "已切换到【电池省电模式】：独显已彻底关闭电源，充电限制已临时放开至 100% 准备出门。"
      else
        if [ -f /sys/bus/pci/rescan ]; then
          echo 1 > /sys/bus/pci/rescan
        fi

        if [ -f "$STATUS_FILE" ]; then
          echo 1 > "$STATUS_FILE"
        fi

        echo "performance" > "$STATE_FILE"
        ${pkgs.libnotify}/bin/notify-send -i video-display "电源管理" "已切换到【插电性能模式】：独显已重新加载就绪，充电限制已恢复为 80% 养护电池。"
      fi
    '')
  ];
}
