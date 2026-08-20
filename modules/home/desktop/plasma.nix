{ config, lib, lilyaGlass, pkgs, ... }:

let
  catppuccinKde = pkgs.catppuccin-kde.override {
    flavour = [ "frappe" ];
    accents = [ "lavender" ];
  };
  catppuccinGtk = pkgs.catppuccin-gtk.override {
    accents = [ "lavender" ];
    size = "compact";
    variant = "frappe";
  };
  catppuccinPapirus = pkgs.catppuccin-papirus-folders.override {
    flavor = "frappe";
    accent = "lavender";
  };
  catppuccinCursors = pkgs.catppuccin-cursors.frappeLavender;

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

    # 1. Catppuccin Frappé + Lavender 外观体系
    workspace = {
      lookAndFeel = "org.kde.breezedark.desktop";
      theme = "default";
      colorScheme = "CatppuccinFrappeLavender";
      iconTheme = "Papirus-Dark";
      cursor = {
        theme = "catppuccin-frappe-lavender-cursors";
        size = lilyaGlass.cursorSize;
      };
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

    # 3. 现代底部浮动面板布局 (启动器 + 任务栏 + 托盘 + 时钟)
    panels = [
      {
        location = "bottom";
        height = 44;
        floating = true;
        opacity = "translucent";
        widgets = [
          {
            kickoff = {
              icon = "nix-snowflake-white";
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

    # 4. 窗口管理器与特效 (启用毛玻璃模糊)
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
          "theme" = "klassy";
        };
      };

      # Klassy 现代圆角毛玻璃微质感
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
          "BlurBehindTitleBar" = true;
          "OpaqueActiveTitleBar" = false;
          "TranslucentTitleBar" = true;
        };
        "TitleBarOpacity" = {
          "ActiveTitleBarOpacity" = 85;
          "InactiveTitleBarOpacity" = 65;
          "OpaqueMaximizedTitleBars" = false;
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
          "widgetStyle" = "klassy";
        };
      };
    };
  };

  home.packages = [
    pkgs.klassy
    catppuccinKde
    catppuccinGtk
    catppuccinPapirus
    catppuccinCursors
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
