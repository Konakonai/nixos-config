{ config, pkgs, lib, ... }:

let
  lilyaGlass = import ./glass-settings.nix;
  gtkThemePackage = pkgs.nordic;
  iconThemePackage = pkgs.colloid-icon-theme;
  cursorThemePackage = pkgs.nordzy-cursor-theme;
  gtkThemeName = lilyaGlass.gtkThemeName;
  iconThemeName = lilyaGlass.iconThemeName;
  qtIconThemeName = lilyaGlass.qtIconThemeName;
  cursorThemeName = lilyaGlass.cursorThemeName;
  kvantumThemeName = lilyaGlass.kvantumThemeName;

  # Nord Kvantum 主题（从仓库 assets 安装）
  kvantumTheme = pkgs.stdenv.mkDerivation {
    pname = "kvantum-theme-nord-light";
    version = "1.0";
    src = ../assets/kvantum/${kvantumThemeName};

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/Kvantum/${kvantumThemeName}
      cp ${kvantumThemeName}.kvconfig $out/share/Kvantum/${kvantumThemeName}/
      cp ${kvantumThemeName}.svg $out/share/Kvantum/${kvantumThemeName}/
      runHook postInstall
    '';

    meta = with lib; {
      description = "Nord Light theme for Kvantum (based on KvAdaptaNordic)";
      platforms = platforms.linux;
    };
  };
in
{
  # 全局光标配置以确保 Wayland/X11 兼容性
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = cursorThemePackage;
    name = cursorThemeName;
    size = 48;
  };

  # 保持并接管原 ~/.Xresources 中的字体与 DPI 配置
  xresources.properties = {
    "Xft.dpi" = 144;
    "Xft.autohint" = 0;
    "Xft.lcdfilter" = "lcddefault";
    "Xft.hintstyle" = "hintfull";
    "Xft.hinting" = 1;
    "Xft.antialias" = 1;
    "Xft.rgba" = "rgb";
  };

  # GTK 与主题配置
  gtk = {
    enable = true;
    theme = {
      package = gtkThemePackage;
      name = gtkThemeName;
    };
    iconTheme = {
      name = iconThemeName;
      package = iconThemePackage;
    };
    cursorTheme = {
      name = cursorThemeName;
      package = cursorThemePackage;
      size = 48;
    };

    gtk2.extraConfig = ''
      gtk-font-name="${lilyaGlass.fonts.sans} ${builtins.toString lilyaGlass.fonts.size}"
    '';

    gtk3.extraConfig = {
      gtk-font-name = "${lilyaGlass.fonts.sans} ${builtins.toString lilyaGlass.fonts.size}";
      gtk-application-prefer-dark-theme = 0;
    };

    gtk4.extraConfig = {
      gtk-font-name = "${lilyaGlass.fonts.sans} ${builtins.toString lilyaGlass.fonts.size}";
      gtk-theme-name = gtkThemeName;
      gtk-application-prefer-dark-theme = 0;
    };
  };

  # Qt 配置：Kvantum + Nord Light 主题
  qt = {
    enable = true;
    platformTheme.name = "kvantum";
    style.name = "kvantum";
  };

  # Kvantum 主题配置文件
  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=${kvantumThemeName}
  '';

  # 安装 Nord Kvantum 主题到 ~/.local/share/Kvantum/
  xdg.dataFile."Kvantum/${kvantumThemeName}/${kvantumThemeName}.kvconfig".source = "${kvantumTheme}/share/Kvantum/${kvantumThemeName}/${kvantumThemeName}.kvconfig";
  xdg.dataFile."Kvantum/${kvantumThemeName}/${kvantumThemeName}.svg".source = "${kvantumTheme}/share/Kvantum/${kvantumThemeName}/${kvantumThemeName}.svg";

  # 自定义 Rime (中州韵) 图标 — 深色填充版，托盘清晰可见
  xdg.dataFile."icons/${iconThemeName}/status/22/fcitx-rime.svg".source = ../assets/fcitx-rime.svg;
  xdg.dataFile."icons/${iconThemeName}/status/24/fcitx-rime.svg".source = ../assets/fcitx-rime.svg;
  xdg.dataFile."icons/${iconThemeName}/status/16/fcitx-rime.svg".source = ../assets/fcitx-rime.svg;
  xdg.dataFile."icons/${qtIconThemeName}/status/22/fcitx-rime.svg".source = ../assets/fcitx-rime.svg;
  xdg.dataFile."icons/${qtIconThemeName}/status/24/fcitx-rime.svg".source = ../assets/fcitx-rime.svg;
  xdg.dataFile."icons/${qtIconThemeName}/status/16/fcitx-rime.svg".source = ../assets/fcitx-rime.svg;
  # hicolor fallback
  xdg.dataFile."icons/hicolor/scalable/apps/fcitx-rime.svg".source = ../assets/fcitx-rime.svg;

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-light";
    cursor-size = 48;
    cursor-theme = cursorThemeName;
    font-name = "${lilyaGlass.fonts.sans} ${builtins.toString lilyaGlass.fonts.size}";
    gtk-theme = gtkThemeName;
    icon-theme = iconThemeName;
    monospace-font-name = "${lilyaGlass.fonts.mono} ${builtins.toString lilyaGlass.fonts.size}";
  };

  home.activation.flatpakThemeIntegration = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    copy_theme_dir() {
      local src="$1"
      local dst="$2"
      if [ -d "$src" ]; then
        if [ -e "$dst" ]; then
          chmod -R u+w "$dst" 2>/dev/null || true
        fi
        rm -rf "$dst"
        mkdir -p "$(dirname "$dst")"
        cp -aL "$src" "$dst"
        chmod -R u+w "$dst"
      fi
    }

    copy_theme_dir "${gtkThemePackage}/share/themes/${gtkThemeName}" "$HOME/.local/share/themes/${gtkThemeName}"
    copy_theme_dir "${gtkThemePackage}/share/themes/${gtkThemeName}-hdpi" "$HOME/.local/share/themes/${gtkThemeName}-hdpi"
    copy_theme_dir "${gtkThemePackage}/share/themes/${gtkThemeName}-xhdpi" "$HOME/.local/share/themes/${gtkThemeName}-xhdpi"
    copy_theme_dir "${iconThemePackage}/share/icons/${iconThemeName}" "$HOME/.local/share/icons/${iconThemeName}"
    copy_theme_dir "${iconThemePackage}/share/icons/${qtIconThemeName}" "$HOME/.local/share/icons/${qtIconThemeName}"

    # 用自定义 rime 图标覆盖 Colloid 主题自带的（复制后执行，避免被覆盖）
    RIME_ICON="${../assets/fcitx-rime.svg}"
    for d in "$HOME/.local/share/icons/${iconThemeName}" "$HOME/.local/share/icons/${qtIconThemeName}"; do
      for s in 16 22 24; do
        if [ -d "$d/status/$s" ]; then
          cp -f "$RIME_ICON" "$d/status/$s/fcitx-rime.svg"
        fi
      done
    done
    # 光标由 home-manager 的 home.pointerCursor 管理，不在这里复制

    # Flatpak filesystem and environment overrides are declared in modules/flatpak.nix.
  '';

  # 设置全局环境变量
  home.sessionVariables = {
    GTK_THEME = gtkThemeName;
    GTK_USE_PORTAL = "1";
    GTK2_RC_FILES = "${config.home.homeDirectory}/.gtkrc-2.0";
    QT_QPA_PLATFORMTHEME = "kvantum";
    QT_STYLE_OVERRIDE = "kvantum";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    XCURSOR_THEME = cursorThemeName;
    XCURSOR_SIZE = "48";
  };
}
