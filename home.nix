{ config, pkgs, lib, inputs, ... }:

let
  lilyaGlass = import ./modules/glass-settings.nix;
in
{
  imports = [
    inputs.zen-browser.homeModules.beta
    inputs.noctalia.homeModules.default

    # 导入拆分后的子配置文件
    ./modules/glass.nix
    ./modules/niri.nix
    ./modules/kitty.nix
    ./modules/shell.nix
    ./modules/theme.nix
    ./modules/fcitx5.nix
    ./modules/desktop.nix
  ];

  home.username = "lilya";
  home.homeDirectory = "/home/lilya";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # Noctalia
  programs.noctalia = {
    enable = true;

    settings = {
      theme = {
        mode = "light";
        source = "builtin";
        builtin = "Nord";
      };

      shell = {
        corner_radius_scale = 1.65;
        font_family = "Noto Sans CJK SC";

        animation = {
          enabled = true;
          speed = 0.92;
        };

        shadow = {
          direction = "down";
          alpha = 0.18;
        };

        panel = {
          transparency_mode = "glass";
          borders = false;
          shadow = false;
          launcher_placement = "centered";
          clipboard_placement = "centered";
          control_center_placement = "floating";
          wallpaper_placement = "floating";
          session_placement = "floating";
          tray = {
            icon_size = 22;
          };
        };
      };

      bar = {
        main = {
          position = "top";
          thickness = 38;
          background_opacity = lilyaGlass.opacity.noctaliaPanels;
          radius = lilyaGlass.radius.panels;
          margin_h = 18;
          margin_v = 10;
          padding = 0;
          widget_spacing = 10;
          scale = 1.0;
          shadow = false;
          auto_hide = false;
          reserve_space = true;
          capsule = false;
          capsule_fill = "surface_variant";
          capsule_radius = lilyaGlass.radius.capsules;
          capsule_opacity = lilyaGlass.opacity.noctaliaCapsules;
          capsule_border = "outline";
          start = [ "launcher" "network" "bluetooth" ];
          center = [ "workspaces" ];
          end = [ "tray" "notifications" "clipboard" "volume" "brightness" "battery" "clock" "control-center" "session" ];
        };
      };

      notification = {
        background_opacity = lilyaGlass.opacity.noctaliaPopups;
        offset_x = 18;
        offset_y = 12;
      };

      osd = {
        background_opacity = lilyaGlass.opacity.noctaliaPopups;
        offset_x = 18;
        offset_y = 12;
      };

      location = {
        monthBeforeDay = true;
      };
    };
  };

  # Zen Browser
  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;
  };

  xdg.configFile."zen/i41yvfec.Default Profile/user.js".text = ''
    user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
    user_pref("browser.tabs.allow_transparent_browser", false);
    user_pref("widget.wayland.opaque-region.enabled", true);
    user_pref("zen.widget.linux.transparency", false);
  '';
  xdg.configFile."zen/i41yvfec.Default Profile/user.js".force = true;

  # GitHub CLI
  programs.gh = {
    enable = true;
  };

  # Yazi File Manager
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    enableBashIntegration = true;

    theme = {
      flavor = {
        dark = "noctalia";
        light = "noctalia";
      };
    };

    plugins = with pkgs.yaziPlugins; {
      "full-border" = {
        package = full-border;
        setup = true;
      };
      git = {
        package = git;
        setup = true;
        settings = {
          order = 1500;
        };
      };
      "recycle-bin" = {
        package = recycle-bin;
        setup = true;
      };
      "smart-enter" = smart-enter;
      "smart-paste" = smart-paste;
      "toggle-pane" = toggle-pane;
      "jump-to-char" = jump-to-char;
      chmod = chmod;
      compress = compress;
      sudo = sudo;
      mount = mount;
      "wl-clipboard" = wl-clipboard;
      drag = drag;
    };

    keymap = {
      mgr.prepend_keymap = [
        {
          on = "<C-n>";
          run = "plugin drag";
          desc = "Drag selected files with ripdrag";
        }
        {
          on = "l";
          run = "plugin smart-enter";
          desc = "Enter directory or open file";
        }
        {
          on = "p";
          run = "plugin smart-paste";
          desc = "Paste into hovered directory or CWD";
        }
        {
          on = "f";
          run = "plugin jump-to-char";
          desc = "Jump to file by first character";
        }
        {
          on = "T";
          run = "plugin toggle-pane min-preview";
          desc = "Show or hide preview pane";
        }
        {
          on = [ "c" "m" ];
          run = "plugin chmod";
          desc = "Chmod selected files";
        }
        {
          on = [ "c" "a" "a" ];
          run = "plugin compress";
          desc = "Archive selected files";
        }
        {
          on = [ "c" "a" "p" ];
          run = "plugin compress -p";
          desc = "Archive selected files with password";
        }
        {
          on = [ "c" "a" "l" ];
          run = "plugin compress -l";
          desc = "Archive selected files with compression level";
        }
        {
          on = "M";
          run = "plugin mount";
          desc = "Open mount manager";
        }
        {
          on = [ "R" "b" ];
          run = "plugin recycle-bin";
          desc = "Open recycle bin menu";
        }
        {
          on = "<C-y>";
          run = "plugin wl-clipboard";
          desc = "Copy selected files to Wayland clipboard";
        }
        {
          on = [ "S" "p" ];
          run = "plugin sudo -- paste";
          desc = "Sudo paste";
        }
        {
          on = [ "S" "r" ];
          run = "plugin sudo -- rename";
          desc = "Sudo rename";
        }
        {
          on = [ "S" "a" ];
          run = "plugin sudo -- create";
          desc = "Sudo create";
        }
        {
          on = [ "S" "d" ];
          run = "plugin sudo -- remove";
          desc = "Sudo trash";
        }
        {
          on = [ "S" "D" ];
          run = "plugin sudo -- remove --permanently";
          desc = "Sudo delete permanently";
        }
        {
          on = [ "S" "m" ];
          run = "plugin sudo -- chmod";
          desc = "Sudo chmod";
        }
      ];
    };

    settings = {
      opener = {
        edit = [
          { run = ''$EDITOR "$@"''; block = true; desc = "System Editor ($EDITOR)"; }
        ];
        zed = [
          { run = ''zeditor "$@"''; orphan = true; desc = "Zed Editor"; }
        ];
        onlyoffice = [
          { run = ''flatpak run org.onlyoffice.desktopeditors "$@"''; orphan = true; desc = "OnlyOffice"; }
        ];
        zen = [
          { run = ''zen-beta "$@"''; orphan = true; desc = "Zen Browser"; }
        ];
        system = [
          { run = ''xdg-open "$@"''; orphan = true; desc = "System Default (xdg-open)"; }
        ];
        archive = [
          { run = ''file-roller "$@"''; orphan = true; desc = "File Roller (Archive Manager)"; }
        ];
      };

      open = {
        rules = [
          { url = "*.md"; use = [ "zed" "edit" "system" "onlyoffice" ]; }
          { url = "*.txt"; use = [ "zed" "edit" "system" ]; }
          { url = "*.json"; use = [ "zed" "edit" "system" ]; }
          { url = "*.toml"; use = [ "zed" "edit" "system" ]; }
          { url = "*.yaml"; use = [ "zed" "edit" "system" ]; }
          { url = "*.yml"; use = [ "zed" "edit" "system" ]; }
          { url = "*.py"; use = [ "zed" "edit" "system" ]; }
          { url = "*.sh"; use = [ "zed" "edit" "system" ]; }
          { url = "*.html"; use = [ "zen" "system" ]; }
          { url = "*.pdf"; use = [ "zen" "system" ]; }
          { url = "*.zip"; use = [ "archive" "system" ]; }
          { url = "*.7z"; use = [ "archive" "system" ]; }
          { url = "*.rar"; use = [ "archive" "system" ]; }
          { url = "*.tar.gz"; use = [ "archive" "system" ]; }
          { url = "*.tar.xz"; use = [ "archive" "system" ]; }
          { url = "*"; use = [ "system" "edit" ]; }
        ];
      };

      plugin = {
        prepend_fetchers = [
          {
            id = "git";
            url = "*";
            run = "git";
            group = "git";
          }
          {
            id = "git";
            url = "*/";
            run = "git";
            group = "git";
          }
        ];
      };
    };
  };

  xdg.configFile."yazi/theme.toml".force = true;

  # Home Packages
  home.packages = with pkgs; [
    # langs
    gcc
    rustup
    go
    nodejs
    python3
    lua

    # misc
    unzip
    zip
    git
    sshfs
    ripgrep
    jq
    nh
    nvd
    paru
    nushell
    trash-cli
    udisks
    ripdrag
    unrar
    _7zz
    p7zip
    pigz
    git-lfs
    file-roller
    nemo-with-extensions

    # hypr utils
    wl-clipboard
    hyprpicker
    swappy
    hyprsunset
    grim
    slurp
    pavucontrol
    mission-center
    resources
    localsend
    zed-editor

    # niri 相关
    cliphist
    wlsunset

    # 引用重归类的 antigravity 包
    (import ./pkgs/antigravity.nix { inherit pkgs lib; })

    # 引用重归类的 splayer 包
    (import ./pkgs/splayer.nix { inherit pkgs lib; })

    # 极度省电与高性能插电一键切换脚本
    (pkgs.writeShellScriptBin "toggle-power-mode" ''
      STATUS_FILE="/sys/class/power_supply/BAT0/extensions/ideapad_laptop/conservation_mode"
      STATE_FILE="$HOME/.config/niri/power-mode-state"

      CURRENT_STATE="performance"
      if [ -f "$STATE_FILE" ]; then
        CURRENT_STATE=$(cat "$STATE_FILE")
      fi

      if [ "$CURRENT_STATE" = "performance" ]; then
        # ========================================
        # 1. 切换到【极度省电模式】
        # ========================================
        
        # 放开充电限制到 100%
        if [ -f "$STATUS_FILE" ]; then
          echo 0 > "$STATUS_FILE"
        fi
        
        # 物理关闭并从总线上移除独显
        if [ -e /sys/bus/pci/devices/0000:01:00.0 ]; then
          echo 1 > /sys/bus/pci/devices/0000:01:00.0/remove || true
        fi
        
        echo "powersave" > "$STATE_FILE"
        ${pkgs.libnotify}/bin/notify-send -i battery-caution "电源管理" "已切换到【电池省电模式】：独显已彻底关闭电源，充电限制已临时放开至 100% 准备出门。"
      else
        # ========================================
        # 2. 切换到【插电高性能模式】
        # ========================================
        
        # 重新扫描 PCI 总线拉回独显
        if [ -f /sys/bus/pci/rescan ]; then
          echo 1 > /sys/bus/pci/rescan
        fi
        
        # 恢复 80% 充电限制保护寿命
        if [ -f "$STATUS_FILE" ]; then
          echo 1 > "$STATUS_FILE"
        fi
        
        echo "performance" > "$STATE_FILE"
        ${pkgs.libnotify}/bin/notify-send -i video-display "电源管理" "已切换到【插电性能模式】：独显已重新加载就绪，充电限制已恢复为 80% 养护电池。"
      fi
    '')
  ];
}
