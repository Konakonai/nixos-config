{ config, pkgs, lib, ... }:

let
  lilyaGlass = import ./glass-settings.nix;
in
{
  # Niri 配置文件后端覆写：普通窗口保持清晰，透明主要交给应用自己的背景层处理。
  xdg.configFile.niri-config.source = lib.mkForce (pkgs.writeText "niri-config.kdl" ''
    ${config.programs.niri.finalConfig}

    include "noctalia.kdl"

    // 普通应用只保留一点点轻透感，避免文字和图标被 compositor 一起淡化。
    window-rule {
        exclude app-id="^kitty$"
        opacity ${lilyaGlass.opacity.windows}
        draw-border-with-background false
    }

    // 聊天与办公类应用优先保证阅读舒适，不参与轻透明。
    window-rule {
        match app-id="^(wechat|wechat-uos|com\\.tencent\\.WeChat|linuxqq|QQ|wemeetapp|com\\.tencent\\.wemeet)$"
        opacity 1.0
        draw-border-with-background false
    }

    // 针对 Kitty 终端：透明交给 Kitty 自己处理，niri 只避免边框背景底色。
    window-rule {
        match app-id="^kitty$"
        draw-border-with-background false
    }

    // Noctalia 面板：半透明 + 毛玻璃模糊效果
    layer-rule {
        match namespace="^noctalia-bar-main$"
        opacity ${lilyaGlass.opacity.layerShell}
        geometry-corner-radius ${builtins.toString lilyaGlass.radius.panels}
        background-effect {
            blur true
            noise 0.0
            saturation 1.0
        }
        popups {
            opacity ${lilyaGlass.opacity.layerPopups}
            geometry-corner-radius ${builtins.toString lilyaGlass.radius.windows}
            background-effect {
                blur true
            }
        }
    }

    // Noctalia dock / 控制中心 / 启动器等 layer-shell
    layer-rule {
        match namespace="^(noctalia-dock|noctalia-control-center|noctalia-launcher|noctalia-session|noctalia-clipboard|notifications|swaync-control-center|launcher|vicinae|waybar)$"
        opacity ${lilyaGlass.opacity.layerShell}
        geometry-corner-radius ${builtins.toString lilyaGlass.radius.windows}
        background-effect {
            blur true
            noise 0.0
            saturation 1.0
        }
        popups {
            opacity ${lilyaGlass.opacity.layerPopups}
            geometry-corner-radius ${builtins.toString lilyaGlass.radius.windows}
            background-effect {
                blur true
            }
        }
    }

    layer-rule {
        match namespace="^noctalia-wallpaper.*"
        place-within-backdrop true
    }

    blur {
        passes ${builtins.toString lilyaGlass.blur.passes}
        offset ${lilyaGlass.blur.offset}
        noise ${lilyaGlass.blur.noise}
        saturation ${lilyaGlass.blur.saturation}
    }
  '');

  # Niri 窗口管理器配置
  programs.niri = {
    settings = {
      prefer-no-csd = true;

      # 启动时运行的程序
      spawn-at-startup = [
        { command = [ "noctalia" ]; }
        { command = [ "xwayland-satellite" ]; }
        { command = [ "xrdb" "-merge" "/home/lilya/.Xresources" ]; }
        { command = [ "wl-paste" "--watch" "cliphist" "store" ]; }
      ];

      # 关闭启动时的快捷键提示
      hotkey-overlay = {
        skip-at-startup = true;
      };

      # Cursor
      cursor = {
        theme = lilyaGlass.cursorThemeName;
        size = 48;
      };

      # 环境变量
      environment = {
        GTK_THEME = lilyaGlass.gtkThemeName;
        GTK_USE_PORTAL = "1";
        NIXOS_OZONE_WL = "1";
        QT_QPA_PLATFORMTHEME = "kvantum";
        QT_STYLE_OVERRIDE = lilyaGlass.qtStyleName;
        ELECTRON_OZONE_PLATFORM_HINT = "wayland";
        XCURSOR_THEME = lilyaGlass.cursorThemeName;
        XCURSOR_SIZE = "48";
      };

      # 输入配置
      input = {
        keyboard.xkb = {
          layout = "us";
          options = "";
        };

        touchpad = {
          tap = true;
          natural-scroll = true;
        };

        mouse = {
          natural-scroll = false;
        };
      };

      outputs = {
        "eDP-1" = {
          mode = {
            width = 3200;
            height = 2000;
            refresh = 60.0;
          };
          scale = 1.75;
          position = {
            x = 0;
            y = 0;
          };
        };

        "DP-2" = {
          focus-at-startup = true;
          mode = {
            width = 3840;
            height = 2160;
            refresh = 60.0;
          };
          scale = 1.5;
          position = {
            x = 1828;
            y = 0;
          };
        };
      };

      # 布局配置
      layout = {
        gaps = 18;

        center-focused-column = "never";
        background-color = "transparent";

        preset-column-widths = [
          { proportion = 0.25; }
          { proportion = 0.5; }
          { proportion = 0.75; }
          { proportion = 1.0; }
        ];

        default-column-width = { proportion = 0.5; };

        focus-ring = {
          enable = true;
          width = 2;
          active.color = lilyaGlass.palette.lavender;
          inactive.color = lilyaGlass.palette.crust;
        };

        border = {
          enable = false;
        };

        shadow = {
          enable = true;
          softness = 28;
          spread = 4;
          offset = {
            x = 0;
            y = 10;
          };
          color = lilyaGlass.palette.shadow;
        };
      };

      # 快捷键配置（基于 niri 默认配置 + noctalia 自定义）
      binds = with config.lib.niri.actions; {
        # 基础操作
        "Mod+Shift+Slash".action.show-hotkey-overlay = [];
        "Mod+Return".action.spawn = [ "kitty" ];
        "Mod+D".action.spawn = [ "noctalia" "msg" "panel-toggle" "launcher" ];
        "Mod+Space".action.spawn = [ "noctalia" "msg" "panel-toggle" "launcher" ];
        "Mod+O" = {
          repeat = false;
          action.toggle-overview = [];
        };

        # 窗口管理
        "Mod+Q" = {
          repeat = false;
          action.close-window = [];
        };
        "Mod+F".action.maximize-column = [];
        "Mod+Shift+F".action.fullscreen-window = [];
        "Mod+C".action.center-column = [];
        "Mod+Ctrl+C".action.center-visible-columns = [];
        "Mod+Ctrl+F".action.expand-column-to-available-width = [];
        "Mod+V".action.toggle-window-floating = [];
        "Mod+Shift+V".action.switch-focus-between-floating-and-tiling = [];
        "Mod+W".action.toggle-column-tabbed-display = [];
        "Mod+Comma".action.consume-window-into-column = [];
        "Mod+Period".action.expel-window-from-column = [];
        "Mod+BracketLeft".action.consume-or-expel-window-left = [];
        "Mod+BracketRight".action.consume-or-expel-window-right = [];
        "Mod+Tab".action.focus-window-down = [];
        "Mod+Shift+Tab".action.focus-window-up = [];

        # 工作区切换
        "Mod+1".action.focus-workspace = [ 1 ];
        "Mod+2".action.focus-workspace = [ 2 ];
        "Mod+3".action.focus-workspace = [ 3 ];
        "Mod+4".action.focus-workspace = [ 4 ];
        "Mod+5".action.focus-workspace = [ 5 ];
        "Mod+6".action.focus-workspace = [ 6 ];
        "Mod+7".action.focus-workspace = [ 7 ];
        "Mod+8".action.focus-workspace = [ 8 ];
        "Mod+9".action.focus-workspace = [ 9 ];
        "Mod+Ctrl+1".action.move-column-to-workspace = [ 1 ];
        "Mod+Ctrl+2".action.move-column-to-workspace = [ 2 ];
        "Mod+Ctrl+3".action.move-column-to-workspace = [ 3 ];
        "Mod+Ctrl+4".action.move-column-to-workspace = [ 4 ];
        "Mod+Ctrl+5".action.move-column-to-workspace = [ 5 ];
        "Mod+Ctrl+6".action.move-column-to-workspace = [ 6 ];
        "Mod+Ctrl+7".action.move-column-to-workspace = [ 7 ];
        "Mod+Ctrl+8".action.move-column-to-workspace = [ 8 ];
        "Mod+Ctrl+9".action.move-column-to-workspace = [ 9 ];

        # 焦点移动
        "Mod+Left".action.focus-column-left = [];
        "Mod+Right".action.focus-column-right = [];
        "Mod+Up".action.focus-window-or-workspace-up = [];
        "Mod+Down".action.focus-window-or-workspace-down = [];
        "Mod+H".action.focus-column-left = [];
        "Mod+L".action.focus-column-right = [];
        "Mod+K".action.focus-window-or-workspace-up = [];
        "Mod+J".action.focus-window-or-workspace-down = [];
        "Mod+Home".action.focus-column-first = [];
        "Mod+End".action.focus-column-last = [];

        # 移动窗口/列
        "Mod+Ctrl+Left".action.move-column-left = [];
        "Mod+Ctrl+Right".action.move-column-right = [];
        "Mod+Ctrl+Up".action.move-window-up-or-to-workspace-up = [];
        "Mod+Ctrl+Down".action.move-window-down-or-to-workspace-down = [];
        "Mod+Ctrl+H".action.move-column-left = [];
        "Mod+Ctrl+L".action.move-column-right = [];
        "Mod+Ctrl+K".action.move-window-up-or-to-workspace-up = [];
        "Mod+Ctrl+J".action.move-window-down-or-to-workspace-down = [];
        "Mod+Ctrl+Home".action.move-column-to-first = [];
        "Mod+Ctrl+End".action.move-column-to-last = [];

        # 多显示器（焦点）
        "Mod+Shift+Left".action.focus-monitor-left = [];
        "Mod+Shift+Right".action.focus-monitor-right = [];
        "Mod+Shift+Up".action.focus-monitor-up = [];
        "Mod+Shift+Down".action.focus-monitor-down = [];
        "Mod+Shift+H".action.focus-monitor-left = [];
        "Mod+Shift+L".action.focus-monitor-right = [];
        "Mod+Shift+K".action.focus-monitor-up = [];
        "Mod+Shift+J".action.focus-monitor-down = [];

        # 多显示器（移动列）
        "Mod+Shift+Ctrl+Left".action.move-column-to-monitor-left = [];
        "Mod+Shift+Ctrl+Right".action.move-column-to-monitor-right = [];
        "Mod+Shift+Ctrl+Up".action.move-column-to-monitor-up = [];
        "Mod+Shift+Ctrl+Down".action.move-column-to-monitor-down = [];
        "Mod+Shift+Ctrl+H".action.move-column-to-monitor-left = [];
        "Mod+Shift+Ctrl+L".action.move-column-to-monitor-right = [];
        "Mod+Shift+Ctrl+K".action.move-column-to-monitor-up = [];
        "Mod+Shift+Ctrl+J".action.move-column-to-monitor-down = [];

        # 多显示器（移动工作区）
        "Mod+Alt+H".action.move-workspace-to-monitor-left = [];
        "Mod+Alt+L".action.move-workspace-to-monitor-right = [];
        "Mod+Alt+K".action.move-workspace-to-monitor-up = [];
        "Mod+Alt+J".action.move-workspace-to-monitor-down = [];

        # 工作区排序
        "Mod+Page_Up".action.focus-workspace-up = [];
        "Mod+Page_Down".action.focus-workspace-down = [];
        "Mod+U".action.focus-workspace-down = [];
        "Mod+I".action.focus-workspace-up = [];
        "Mod+Ctrl+Page_Down".action.move-column-to-workspace-down = [];
        "Mod+Ctrl+Page_Up".action.move-column-to-workspace-up = [];
        "Mod+Ctrl+U".action.move-column-to-workspace-down = [];
        "Mod+Ctrl+I".action.move-column-to-workspace-up = [];
        "Mod+Shift+Page_Up".action.move-workspace-up = [];
        "Mod+Shift+Page_Down".action.move-workspace-down = [];
        "Mod+Shift+U".action.move-workspace-down = [];
        "Mod+Shift+I".action.move-workspace-up = [];

        # 鼠标滚轮
        "Mod+WheelScrollDown" = {
          cooldown-ms = 150;
          action.focus-workspace-down = [];
        };
        "Mod+WheelScrollUp" = {
          cooldown-ms = 150;
          action.focus-workspace-up = [];
        };
        "Mod+Ctrl+WheelScrollDown" = {
          cooldown-ms = 150;
          action.move-column-to-workspace-down = [];
        };
        "Mod+Ctrl+WheelScrollUp" = {
          cooldown-ms = 150;
          action.move-column-to-workspace-up = [];
        };
        "Mod+WheelScrollRight".action.focus-column-right = [];
        "Mod+WheelScrollLeft".action.focus-column-left = [];
        "Mod+Ctrl+WheelScrollRight".action.move-column-right = [];
        "Mod+Ctrl+WheelScrollLeft".action.move-column-left = [];

        # 调整窗口大小
        "Mod+R".action.switch-preset-column-width = [];
        "Mod+Shift+R".action.switch-preset-column-width-back = [];
        "Mod+Ctrl+Shift+R".action.switch-preset-window-height = [];
        "Mod+Ctrl+R".action.reset-window-height = [];
        "Mod+Minus".action.set-column-width = [ "-10%" ];
        "Mod+Equal".action.set-column-width = [ "+10%" ];
        "Mod+Shift+Minus".action.set-window-height = [ "-10%" ];
        "Mod+Shift+Equal".action.set-window-height = [ "+10%" ];

        # 截图
        "Mod+Shift+S".action.screenshot = [];
        "Mod+Ctrl+A".action.spawn = [ "/home/lilya/.nix-profile/bin/codex-desktop" "--appshot" ];
        "Print".action.screenshot = [];
        "Ctrl+Print".action.screenshot-screen = [];
        "Alt+Print".action.screenshot-window = [];

        # Noctalia 控制
        "Mod+Escape".action.spawn = [ "noctalia" "msg" "session" "lock" ];
        "Mod+M".action.spawn = [ "noctalia" "msg" "panel-toggle" "session" ];
        "Mod+N".action.spawn = [ "noctalia" "msg" "panel-toggle" "control-center" "notifications" ];
        "Mod+X".action.spawn = [ "noctalia" "msg" "panel-toggle" "control-center" ];
        "Mod+Shift+C".action.spawn = [ "noctalia" "msg" "panel-toggle" "clipboard" ];

        # 音量控制
        "XF86AudioRaiseVolume".action.spawn = [ "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+" ];
        "XF86AudioLowerVolume".action.spawn = [ "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-" ];
        "XF86AudioMute".action.spawn = [ "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle" ];

        # 亮度控制
        "XF86MonBrightnessUp".action.spawn = [ "brightnessctl" "set" "+5%" ];
        "XF86MonBrightnessDown".action.spawn = [ "brightnessctl" "set" "5%-" ];

        # 系统
        "Mod+Shift+E".action.quit = [];
        "Mod+Shift+P".action.power-off-monitors = [];
      };
      # 窗口规则
      window-rules = [
        {
          geometry-corner-radius = let
            radius = lilyaGlass.radius.windows;
          in {
            top-left = radius;
            top-right = radius;
            bottom-left = radius;
            bottom-right = radius;
          };
          draw-border-with-background = false;
          clip-to-geometry = true;
        }
      ];

      # 动画配置
      animations = {
        enable = true;
      };
    };
  };
}
