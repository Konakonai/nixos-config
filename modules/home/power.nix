{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "toggle-power-mode" ''
      STATUS_FILE="/sys/class/power_supply/BAT0/extensions/ideapad_laptop/conservation_mode"
      STATE_FILE="$HOME/.config/niri/power-mode-state"
      GPU_POWER_CONTROL="/sys/bus/pci/devices/0000:01:00.0/power/control"

      CURRENT_STATE="performance"
      if [ -f "$STATE_FILE" ]; then
        CURRENT_STATE=$(cat "$STATE_FILE")
      fi

      if [ "$CURRENT_STATE" = "performance" ]; then
        if [ -f "$STATUS_FILE" ]; then
          echo 0 > "$STATUS_FILE"
        fi

        # 启用独显自动悬挂（RTD3 省电），在没有独显程序运行时独显会自动断电 (D3cold)
        if [ -f "$GPU_POWER_CONTROL" ]; then
          echo "auto" > "$GPU_POWER_CONTROL"
        fi

        echo "powersave" > "$STATE_FILE"
        ${pkgs.libnotify}/bin/notify-send -i battery-caution "电源管理" "已切换到【电池省电模式】：独显已开启动态省电休眠，充电限制已临时放开至 100% 准备出门。"
      else
        # 强制独显通电保持唤醒
        if [ -f "$GPU_POWER_CONTROL" ]; then
          echo "on" > "$GPU_POWER_CONTROL"
        fi

        if [ -f "$STATUS_FILE" ]; then
          echo 1 > "$STATUS_FILE"
        fi

        echo "performance" > "$STATE_FILE"
        ${pkgs.libnotify}/bin/notify-send -i video-display "电源管理" "已切换到【插电性能模式】：独显已恢复持续唤醒，充电限制已恢复为 80% 养护电池。"
      fi
    '')
  ];
}
