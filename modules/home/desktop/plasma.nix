{ config, lib, lilyaGlass, pkgs, ... }:

let
  kdeGlobals = "${config.xdg.configHome}/kdeglobals";
  kwinConfig = "${config.xdg.configHome}/kwinrc";
  powerDevilConfig = "${config.xdg.configHome}/powerdevilrc";

  writeKdeConfig = file: group: key: value: ''
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file ${lib.escapeShellArg file} \
      --group ${lib.escapeShellArg group} \
      --key ${lib.escapeShellArg key} \
      ${lib.escapeShellArg value}
  '';
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

    # 1. 声明式 Workspace 外观体系
    workspace = {
      theme = "MacTahoe-Light";
      colorScheme = "BreezeLight";
      iconTheme = "WhiteSur";
      cursor = {
        theme = lilyaGlass.cursorThemeName;
        size = lilyaGlass.cursorSize;
      };
      lookAndFeel = "org.kde.breeze.desktop";
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

    # 3. macOS 式顶栏 + 底部浮动 Dock 面板
    panels = [
      # 顶部状态栏：高度 30，贴顶，包含启动菜单、全局菜单、居中时钟和系统托盘
      {
        location = "top";
        height = 30;
        floating = false;
        widgets = [
          "org.kde.plasma.kickoff"
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

      # 底部 Dock：居中悬浮、自适应长度、图标任务栏 + 废纸篓
      {
        location = "bottom";
        alignment = "center";
        height = 56;
        lengthMode = "fit";
        floating = true;
        hiding = "dodgewindows";
        widgets = [
          {
            iconTasks = {
              launchers = [
                "applications:org.kde.dolphin.desktop"
                "applications:kitty.desktop"
                "applications:zen-beta.desktop"
                "applications:codex.desktop"
                "applications:systemsettings.desktop"
              ];
            };
          }
          "org.kde.plasma.trash"
        ];
      }
    ];

    # 4. 窗口管理器与特效 (启用毛玻璃模糊)
    kwin = {
      effects = {
        blur.enable = true;
      };
    };

    # 5. 快捷键
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

    # 6. 底层与 Klassy 细粒度主题定制 (交通灯按钮与毛玻璃融合)
    configFile = {
      "klassy/klassyrc" = {
        "Button" = {
          "ButtonShape" = "TrafficLights";
          "ButtonIconStyle" = "macOS";
        };
        "TitleBar" = {
          "BlurBehindTitleBar" = true;
          "TranslucentTitleBar" = true;
          "OpaqueActiveTitleBar" = false;
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
      "kwinrc" = {
        "org.kde.kdecoration2" = {
          "library" = "org.kde.klassy";
          "theme" = "klassy";
        };
      };
    };
  };

  home.packages = [
    pkgs.klassy
    pkgs.lilya.mactahoe-kde
    pkgs.whitesur-icon-theme
    pkgs.whitesur-kde
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
