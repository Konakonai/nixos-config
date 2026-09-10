{ lib, lilyaTheme, pkgs, ... }:

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

    # Keep the existing suspend workaround until resume is tested separately.
    powerdevil = {
      AC = {
        autoSuspend.action = "nothing";
        whenLaptopLidClosed = "turnOffScreen";
      };
      battery = {
        autoSuspend.action = "nothing";
        whenLaptopLidClosed = "turnOffScreen";
      };
    };

    # 1. 浅色桌面外观体系
    workspace = {
      lookAndFeel = lilyaTheme.theme.plasma.lookAndFeel;
      theme = lilyaTheme.theme.plasma.workspace;
      colorScheme = lilyaTheme.theme.plasma.colorScheme;
      iconTheme = lilyaTheme.iconThemeName;
      cursor = {
        theme = lilyaTheme.cursorThemeName;
        size = lilyaTheme.cursorSize;
      };
    };

    # 2. 统一字体管理
    fonts = {
      general = {
        family = lilyaTheme.fonts.sans;
        pointSize = lilyaTheme.fonts.size;
      };
      fixedWidth = {
        family = lilyaTheme.fonts.mono;
        pointSize = lilyaTheme.fonts.terminalSize;
      };
      small = {
        family = lilyaTheme.fonts.sans;
        pointSize = lilyaTheme.fonts.size - 2;
      };
      toolbar = {
        family = lilyaTheme.fonts.sans;
        pointSize = lilyaTheme.fonts.size;
      };
      menu = {
        family = lilyaTheme.fonts.sans;
        pointSize = lilyaTheme.fonts.size;
      };
      windowTitle = {
        family = lilyaTheme.fonts.sans;
        pointSize = lilyaTheme.fonts.size;
      };
    };

    # 3. 现代化底部浮动面板布局
    panels = [
      {
        location = "bottom";
        height = 44;
        floating = true;
        opacity = lilyaTheme.opacity.plasmaPanel;
        widgets = [
          {
            kickoff = {
              icon = "nix-snowflake";
            };
          }
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
          "org.kde.plasma.panelspacer"
          "org.kde.plasma.systemtray"
          {
            digitalClock = {
              time.format = "24h";
              date.enable = false;
            };
          }
        ];
      }
    ];

    # 4. 窗口管理器与特效（关闭背景模糊）
    kwin = {
      effects.blur.enable = lilyaTheme.effects.backgroundBlur;
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

    # 6. 底层与 Klassy 现代微质感配置
    configFile = {
      # 标准现代窗口控制按钮（放置于右侧）
      "kwinrc" = {
        "org.kde.kdecoration2" = {
          "BorderSize" = "None";
          "BorderSizeAuto" = false;
          "ButtonsOnLeft" = "";
          "ButtonsOnRight" = "IAX";
          "library" = "org.kde.klassy";
          "theme" = lilyaTheme.theme.qtStyle;
        };
      };

      # Klassy 现代圆角与实色标题栏
      "klassy/klassyrc" = {
        "Button" = {
          "ButtonIconStyle" = "StyleKlassy";
          "ButtonShape" = "ShapeSmallCircle";
        };
        "ButtonBehaviour" = {
          "ShowBackgroundNormallyActive" = true;
          "ShowBackgroundNormallyInactive" = false;
          "ShowIconNormallyActive" = true;
          "ShowIconNormallyInactive" = true;
          "UnisonHovering" = false;
        };
        "ButtonColors" = {
          "ButtonBackgroundColorsActive" = "Accent";
          "ButtonBackgroundColorsInactive" = "TitleBarTextAuto";
          "CloseButtonIconColorActive" = "AsSelected";
          "CloseButtonIconColorInactive" = "AsSelected";
        };
        "TitleBar" = {
          "BlurBehindTitleBar" = false;
          "OpaqueActiveTitleBar" = true;
          "TranslucentTitleBar" = false;
        };
        "TitleBarOpacity" = {
          "ActiveTitleBarOpacity" = lilyaTheme.opacity.plasmaTitlebarActive;
          "InactiveTitleBarOpacity" = lilyaTheme.opacity.plasmaTitlebarInactive;
          "OpaqueMaximizedTitleBars" = true;
        };
        "Windeco" = {
          "BoldButtonIcons" = "BoldIconsBold";
          "ButtonIconStyle" = "StyleKlassy";
          "ButtonShape" = "ShapeSmallCircle";
          "DrawTitleBarSeparator" = false;
          "IconSize" = "IconMedium";
          "MatchTitleBarToApplicationColor" = true;
          "WindowCornerRadius" = 10;
        };
      };

      "kdeglobals" = {
        "General" = {
          "TerminalApplication" = lib.getExe pkgs.kitty;
          "TerminalService" = "";
        };
        "KDE" = {
          "widgetStyle" = lilyaTheme.theme.qtStyle;
        };
        "Sounds" = {
          "Theme" = lilyaTheme.theme.sound;
        };
      };
    };
  };

  home.packages = [
    pkgs.klassy
    pkgs.colloid-icon-theme
    pkgs.catppuccin-cursors.frappeLavender
    pkgs.adw-gtk3
  ];

  # Both Dolphin and Plasma update KDE service metadata. Rebuild the shared
  # cache once after both activation steps instead of doing the same full scan
  # twice on every boot and rebuild.
  home.activation.refreshKServiceCache =
    lib.hm.dag.entryAfter [ "configureDolphin" "writeBoundary" ] ''
      ${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental >/dev/null
    '';
}
