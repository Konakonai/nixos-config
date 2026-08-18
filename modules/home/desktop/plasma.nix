{ config, lib, lilyaGlass, pkgs, ... }:

let
  powerDevilConfig = "${config.xdg.configHome}/powerdevilrc";

  writePowerDevilConfig = profile: key: value: ''
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file ${lib.escapeShellArg powerDevilConfig} \
      --group ${lib.escapeShellArg profile} \
      --group "SuspendAndShutdown" \
      --key ${lib.escapeShellArg key} \
      ${lib.escapeShellArg value}
  '';
in
{
  # A desktop service lets KGlobalAccel own Meta+Return without wrapping Kitty.
  xdg.dataFile."applications/lilya-kitty-shortcut.desktop".text = ''
    [Desktop Entry]
    Name=Kitty
    Comment=Open the terminal
    Exec=${lib.getExe pkgs.kitty}
    Icon=kitty
    Terminal=false
    Type=Application
    NoDisplay=true
    X-KDE-Shortcuts=Meta+Return
  '';

  programs.plasma = {
    enable = true;

    # 1. 统一纯正 macOS (WhiteSur) 视觉体系
    workspace = {
      lookAndFeel = "com.github.vinceliuice.WhiteSur";
      theme = "WhiteSur";
      colorScheme = "WhiteSur";
      iconTheme = "WhiteSur";
      cursor = {
        theme = lilyaGlass.cursorThemeName;
        size = lilyaGlass.cursorSize;
      };
      wallpaper = "${pkgs.whitesur-kde}/share/wallpapers/WhiteSur-light/contents/images/5120x2880.jpg";
    };

    # 2. 统一字体管理
    fonts = {
      general = {
        family = lilyaGlass.fonts.sans;
        pointSize = lilyaGlass.fonts.size;
      };
      fixedWidth = {
        family = lilyaGlass.fonts.mono;
        pointSize = lilyaGlass.fonts.terminalSize;
      };
      small = {
        family = lilyaGlass.fonts.sans;
        pointSize = lilyaGlass.fonts.size - 2;
      };
      toolbar = {
        family = lilyaGlass.fonts.sans;
        pointSize = lilyaGlass.fonts.size;
      };
      menu = {
        family = lilyaGlass.fonts.sans;
        pointSize = lilyaGlass.fonts.size;
      };
      windowTitle = {
        family = lilyaGlass.fonts.sans;
        pointSize = lilyaGlass.fonts.size;
      };
    };

    # 3. macOS 布局：顶部透明状态栏 + 底部浮动居中透明 Dock
    panels = [
      # 顶部状态栏：半透明、贴顶、Apple 启动菜单、全局菜单、居中时钟和系统托盘
      {
        location = "top";
        height = 30;
        floating = false;
        opacity = "translucent";
        widgets = [
          {
            kickoff = {
              icon = "start-here";
            };
          }
          "org.kde.plasma.appmenu"
          "org.kde.plasma.panelspacer"
          {
            digitalClock = {
              time.format = "24h";
              date.enable = false;
            };
          }
          "org.kde.plasma.panelspacer"
          "org.kde.plasma.systemtray"
        ];
      }

      # 底部 Dock：居中悬浮、自适应长度、半透明、智能避让窗口、常驻核心应用（移除垃圾桶）
      {
        location = "bottom";
        alignment = "center";
        height = 56;
        lengthMode = "fit";
        floating = true;
        opacity = "translucent";
        hiding = "dodgewindows";
        widgets = [
          {
            iconTasks = {
              launchers = [
                "applications:org.kde.dolphin.desktop"
                "applications:kitty.desktop"
                "applications:zen-beta.desktop"
                "applications:codex-desktop.desktop"
                "applications:systemsettings.desktop"
              ];
            };
          }
        ];
      }
    ];

    # 4. 窗口管理器特效 (启用毛玻璃模糊)
    kwin = {
      effects = {
        blur.enable = true;
      };
    };

    # 5. 全局快捷键
    shortcuts = {
      kwin = {
        "Overview" = [ "Meta+O" "Meta+W" ];
        "Window Close" = "Meta+Q";
        "Window Maximize" = "Meta+F";
        "Window Fullscreen" = "Meta+Shift+F";
      };
      plasmashell = {
        "activate application launcher" = [ "Meta+Space" "Alt+F1" ];
        "manage activities" = "none";
      };
    };

    # 6. 底层与 Klassy macOS 交通灯红绿灯定制
    configFile = {
      # 窗口管理器按钮布局：交通灯放左侧（X=Close, I=Minimize, A=Maximize），右侧留空
      "kwinrc" = {
        "org.kde.kdecoration2" = {
          "BorderSize" = "None";
          "BorderSizeAuto" = false;
          "ButtonsOnLeft" = "XIA";
          "ButtonsOnRight" = "";
          "library" = "org.kde.klassy";
          "theme" = "klassy";
        };
      };

      # Klassy 完整的 macOS 红绿灯与半透明毛玻璃配置
      "klassy/klassyrc" = {
        "Button" = {
          "ButtonIconStyle" = "macOS";
          "ButtonShape" = "TrafficLights";
        };
        "ButtonBehaviour" = {
          "ShowBackgroundNormallyActive" = true;
          "ShowBackgroundNormallyInactive" = true;
          "ShowCloseBackgroundNormallyActive" = true;
          "ShowCloseBackgroundNormallyInactive" = true;
          "ShowCloseIconNormallyActive" = false;
          "ShowCloseIconNormallyInactive" = false;
          "ShowIconNormallyActive" = false;
          "ShowIconNormallyInactive" = false;
          "ShowCloseOutlineNormallyActive" = true;
          "ShowCloseOutlineNormallyInactive" = true;
          "ShowOutlineNormallyActive" = true;
          "ShowOutlineNormallyInactive" = true;
          "UnisonHovering" = true;
          "VaryColorCloseBackgroundActive" = "Opaque";
          "VaryColorCloseBackgroundInactive" = "Opaque";
        };
        "ButtonColors" = {
          "ButtonBackgroundColorsActive" = "AccentTrafficLights";
          "ButtonBackgroundColorsInactive" = "AccentTrafficLights";
          "ButtonBackgroundOpacityActive" = 85;
          "ButtonBackgroundOpacityInactive" = 50;
          "CloseButtonIconColorActive" = "AsSelected";
          "CloseButtonIconColorInactive" = "AsSelected";
          "LockButtonColorsActiveInactive" = false;
        };
        "ButtonSizing" = {
          "ButtonSpacingLeft" = 10;
          "FullHeightButtonSpacingRight" = 2;
        };
        "TitleBar" = {
          "BlurBehindTitleBar" = true;
          "OpaqueActiveTitleBar" = false;
          "TranslucentTitleBar" = true;
        };
        "TitleBarOpacity" = {
          "ActiveTitleBarOpacity" = 65;
          "InactiveTitleBarOpacity" = 45;
          "OpaqueMaximizedTitleBars" = false;
        };
        "Windeco" = {
          "BoldButtonIcons" = "BoldIconsBold";
          "BoldTitle" = false;
          "ButtonIconStyle" = "StylemacOS";
          "ButtonShape" = "ShapeSmallCircle";
          "DrawTitleBarSeparator" = false;
          "IconSize" = "IconMedium";
          "MatchTitleBarToApplicationColor" = true;
          "WindowCornerRadius" = 12;
        };
      };

      "kdeglobals" = {
        "General" = {
          "TerminalApplication" = lib.getExe pkgs.kitty;
          "TerminalService" = "";
        };
        "KDE" = {
          "widgetStyle" = "klassy";
        };
      };
    };
  };

  home.packages = [
    pkgs.klassy
    pkgs.whitesur-icon-theme
    pkgs.whitesur-kde
    pkgs.whitesur-gtk-theme
    pkgs.lilya.mactahoe-kde
  ];

  # 保留针对电源管理与缓存的独立触发脚本
  home.activation.configurePlasmaPowerManagement = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    # PowerDevil handles lid events independently of logind. Keep both power
    # profiles awake on lid close so the panel can turn off without entering
    # the unreliable NVIDIA s2idle resume path.
    ${writePowerDevilConfig "AC" "AutoSuspendAction" "0"}
    ${writePowerDevilConfig "AC" "LidAction" "64"}
    ${writePowerDevilConfig "Battery" "AutoSuspendAction" "0"}
    ${writePowerDevilConfig "Battery" "LidAction" "64"}

    if ${pkgs.systemd}/bin/systemctl --user is-active --quiet plasma-powerdevil.service; then
      ${pkgs.systemd}/bin/systemctl --user restart plasma-powerdevil.service
    fi
  '';

  # Both Dolphin and Plasma update KDE service metadata. Rebuild the shared
  # cache once after both activation steps instead of doing the same full scan
  # twice on every boot and rebuild.
  home.activation.refreshKServiceCache =
    lib.hm.dag.entryAfter [ "configureDolphin" "writeBoundary" ] ''
      ${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental >/dev/null
    '';
}
