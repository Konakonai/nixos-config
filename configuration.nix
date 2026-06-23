{ config, pkgs, lib, inputs, ... }:

let
  lilyaGlass = import ./modules/glass-settings.nix;

  # 自定义 SDDM 主题：Catppuccin Latte 基底 + Nord 配色覆写
  colloidDefault = pkgs.colloid-icon-theme;
  custom-sddm-theme = ((pkgs.catppuccin-sddm.override {
    flavor = "latte";
    accent = "blue";
    font = "JetBrains Maple Mono";
    fontSize = "11";
    background = "/etc/sddm-wallpaper.jpg";
  }).overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      for f in $out/share/sddm/themes/catppuccin-latte-blue/Components/*.qml; do
        substituteInPlace $f --replace-quiet 'radius: 3' 'radius: 12'
        substituteInPlace $f --replace-quiet 'radius: 5.4' 'radius: 12'
        substituteInPlace $f --replace-quiet 'radius: 5' 'radius: 12'
      done

      # 使用 Colloid 图标主题的 symbolic 图标
      cp ${colloidDefault}/share/icons/Colloid-Light/actions/symbolic/system-shutdown-symbolic.svg $out/share/sddm/themes/catppuccin-latte-blue/icons/power.svg
      cp ${colloidDefault}/share/icons/Colloid-Light/actions/symbolic/system-reboot-symbolic.svg $out/share/sddm/themes/catppuccin-latte-blue/icons/reboot.svg
      cp ${colloidDefault}/share/icons/Colloid-Light/actions/symbolic/system-suspend-symbolic.svg $out/share/sddm/themes/catppuccin-latte-blue/icons/sleep.svg
      cp ${colloidDefault}/share/icons/Colloid-Light/actions/symbolic/settings-symbolic.svg $out/share/sddm/themes/catppuccin-latte-blue/icons/settings.svg
      # 替换颜色为 Nord Frost 蓝
      for f in $out/share/sddm/themes/catppuccin-latte-blue/icons/*.svg; do
        substituteInPlace $f --replace-quiet '#363636' '#5e81ac'
        substituteInPlace $f --replace-quiet '#1e66f5' '#5e81ac'
        substituteInPlace $f --replace-quiet 'fill="currentColor"' 'fill="#5e81ac"'
      done
    '';
  }));


in
{
  imports = [
    ./hardware-configuration.nix
  ];

  # 启用 niri
  programs.niri = {
    enable = true;
    package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
  };

  # Nix / flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nix.optimise.automatic = true;

  nixpkgs.config.allowUnfree = true;

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "tun" ];

  # Networking (完全按照 NixOS 官方标准配置)
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  networking.firewall = {
    enable = true;
    
    # 信任 mihomo TUN 虚拟网卡接口
    trustedInterfaces = [ "mihomo" ];
    
    # 允许不对称路由（关键：关闭严格的反向路径过滤，防止防火墙丢弃 TUN 流量）
    checkReversePath = false;
    
    # 使用 nftables 时放行 TUN 的反向路径过滤规则
    extraReversePathFilterRules = ''
      iifname { "mihomo" } accept comment "trusted interface"
    '';

    # 开放 OpenList 端口以允许局域网内其他设备访问
    allowedTCPPorts = [ 5244 ];

    # KDE Connect 端口放行
    allowedTCPPortRanges = [
      { from = 1714; to = 1764; }
    ];
    allowedUDPPortRanges = [
      { from = 1714; to = 1764; }
    ];
  };
  
  # 启用科大镜像和 niri 缓存
  nix.settings = {
    substituters = [
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://cache.nixos.org"
      "https://niri.cachix.org"
      "https://noctalia.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niri.cachix.org-1:WvPHH8MAB75+grGROmO1CwMgxMO47J3AaOEGg3RL0c0="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  # Time / locale
  time.timeZone = "Asia/Taipei";
  i18n.defaultLocale = "zh_CN.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.UTF-8";
    LC_IDENTIFICATION = "zh_CN.UTF-8";
    LC_MEASUREMENT = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
    LC_NAME = "zh_CN.UTF-8";
    LC_NUMERIC = "zh_CN.UTF-8";
    LC_PAPER = "zh_CN.UTF-8";
    LC_TELEPHONE = "zh_CN.UTF-8";
    LC_TIME = "zh_CN.UTF-8";
  };

  # SDDM + Nord 配色主题
  services.xserver.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "catppuccin-latte-blue";
    settings = {
      Theme = {
        CursorTheme = lilyaGlass.cursorThemeName;
        CursorSize = "48";
      };
    };
  };

  # SDDM 壁纸声明式管理
  environment.etc."sddm-wallpaper.jpg".source = ./assets/sddm-wallpaper.jpg;

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # NVIDIA proprietary driver
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;

    # Closed-source NVIDIA kernel module.
    open = false;

    nvidiaSettings = true;

    # 对笔记本休眠/唤醒更友好；如果 suspend 出问题，可以改成 false。
    powerManagement.enable = true;
    powerManagement.finegrained = false;

    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Sound
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # 启用 gvfs 以支持 Nemo/Nautilus 文件管理器挂载 WebDAV 等网络位置
  services.gvfs.enable = true;

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # 电源管理 (Noctalia 需要)
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;
  systemd.services.set-balanced-profile = {
    wantedBy = [ "multi-user.target" ];
    after = [ "power-profiles-daemon.service" ];
    script = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced";
    serviceConfig.Type = "oneshot";
  };

  # 允许普通用户 lilya 修改 ThinkBook (ideapad_laptop 驱动) 电池养护模式设置
  systemd.services.battery-conservation-permissions = {
    description = "Set permissions for ThinkBook battery conservation mode";
    after = [ "systemd-modules-load.service" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      for i in $(seq 1 15); do
        if [ -f /sys/class/power_supply/BAT0/extensions/ideapad_laptop/conservation_mode ]; then
          chown lilya:users /sys/class/power_supply/BAT0/extensions/ideapad_laptop/conservation_mode
          chmod 664 /sys/class/power_supply/BAT0/extensions/ideapad_laptop/conservation_mode
          exit 0
        fi
        sleep 1
      done
    '';
    serviceConfig.Type = "oneshot";
  };

  # OpenList 聚合网盘 WebDAV 服务（常驻后台运行）
  systemd.services.openlist = {
    description = "OpenList Service";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.openlist}/bin/OpenList server --data /home/lilya/.config/openlist";
      Restart = "always";
      User = "lilya";
      Group = "users";
    };
  };

  # Printing
  services.printing.enable = true;

  # Input method: Fcitx5 + Rime + 雾凇拼音
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";

    fcitx5 = {
      waylandFrontend = false;

      addons = with pkgs; [
        fcitx5-gtk
        kdePackages.fcitx5-qt
        kdePackages.fcitx5-configtool
        fcitx5-nord

        (fcitx5-rime.override {
          rimeDataPkgs = with pkgs; [
            rime-data
            rime-ice
          ];
        })
      ];
    };
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";

    XMODIFIERS = "@im=fcitx";
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "fcitx";
  };

  # Fonts
  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      jetbrains-mono
      nerd-fonts.jetbrains-mono

      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji

      source-han-sans
      source-han-serif
      sarasa-gothic
    ];

    fontconfig.defaultFonts = {
      monospace = [
        lilyaGlass.fonts.mono
        "Noto Sans Mono CJK SC"
      ];

      sansSerif = [
        lilyaGlass.fonts.sans
        "Noto Sans"
      ];

      serif = [
        lilyaGlass.fonts.serif
        "Noto Serif"
      ];

      emoji = [
        "Noto Color Emoji"
      ];
    };
  };

  # Flatpak / AppImage
  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config = {
      common = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
      niri = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
    };
  };

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  programs.gamemode.enable = true;

  # KDE Connect
  programs.kdeconnect.enable = true;

  # Shell
  programs.fish.enable = true;

  programs.dconf.enable = true;

  # Useful for some upstream binary apps.
  programs.nix-ld.enable = true;

  # User
  users.users.lilya = {
    isNormalUser = true;
    description = "lilya";
    shell = pkgs.fish;

    extraGroups = [
      "networkmanager"
      "wheel"
      "audio"
      "video"
      "input"
    ];
  };

  # mihomo 代理服务
  services.mihomo = {
    enable = true;
    tunMode = true;
    configFile = "/home/lilya/.config/mihomo/config.yaml";
    webui = pkgs.metacubexd;
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    openlist
    vlc
    git
    pciutils
    usbutils
    ripgrep
    fd
    jq
    tree
    unzip
    p7zip
    killall
    btop
    fastfetch

    appimage-run

    # niri 相关
    xwayland-satellite
    brightnessctl
    imagemagick

    (callPackage ./pkgs/cc-switch-cli/default.nix {})
    (callPackage ./pkgs/codex.nix {})
    
    libsForQt5.qtstyleplugin-kvantum
    kdePackages.qtstyleplugin-kvantum
    custom-sddm-theme
    colloidDefault
    nordzy-cursor-theme
    opencode
  ];

  system.stateVersion = "26.05";
}
