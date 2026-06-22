{ config, pkgs, lib, ... }:

let
  lilyaGlass = import ./glass-settings.nix;
  gtkThemePackage = pkgs.nordic;
  iconThemePackage = pkgs.nordzy-icon-theme;
  cursorThemePackage = pkgs.nordzy-cursor-theme;
  gtkThemeName = lilyaGlass.gtkThemeName;
  iconThemeName = lilyaGlass.iconThemeName;
  qtIconThemeName = lilyaGlass.qtIconThemeName;
  cursorThemeName = lilyaGlass.cursorThemeName;
  qtctSettings = {
    Appearance = {
      custom_palette = true;
      icon_theme = qtIconThemeName;
      standard_dialogs = "xdgdesktopportal";
      style = lilyaGlass.qtStyleName;
    };

    Fonts = {
      fixed = "\"${lilyaGlass.fonts.mono},${builtins.toString lilyaGlass.fonts.size},-1,5,400,0,0,0,0,0,0,0,0,0,0,1\"";
      general = "\"${lilyaGlass.fonts.sans},${builtins.toString lilyaGlass.fonts.size},-1,5,400,0,0,0,0,0,0,0,0,0,0,1\"";
    };

    Interface = {
      activate_item_on_single_click = 1;
      buttonbox_layout = 0;
      cursor_flash_time = 1000;
      dialog_buttons_have_icons = 1;
      double_click_interval = 400;
      keyboard_scheme = 4;
      menus_have_icons = true;
      show_shortcuts_in_context_menus = true;
      underline_shortcut = 1;
      wheel_scroll_lines = 3;
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

  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style = {
      name = lilyaGlass.qtStyleName;
      package = pkgs.adwaita-qt;
    };
  };

  qt.qt5ctSettings = qtctSettings // {
    Appearance = qtctSettings.Appearance // {
      color_scheme_path = "${config.home.homeDirectory}/.config/qt5ct/colors/noctalia.conf";
    };
  };

  qt.qt6ctSettings = qtctSettings // {
    Appearance = qtctSettings.Appearance // {
      color_scheme_path = "${config.home.homeDirectory}/.config/qt6ct/colors/noctalia.conf";
    };
  };


  xdg.configFile."qt5ct/qt5ct.conf".force = true;
  xdg.configFile."qt6ct/qt6ct.conf".force = true;

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
    copy_theme_dir "${cursorThemePackage}/share/icons/${cursorThemeName}" "$HOME/.local/share/icons/${cursorThemeName}"

    if ${pkgs.flatpak}/bin/flatpak --user remotes >/dev/null 2>&1; then
      ${pkgs.flatpak}/bin/flatpak override --user \
        --filesystem=xdg-config/gtk-3.0:ro \
        --filesystem=xdg-config/gtk-4.0:ro \
        --filesystem=xdg-config/qt5ct:ro \
        --filesystem=xdg-config/qt6ct:ro \
        --filesystem=xdg-data/themes:ro \
        --filesystem=xdg-data/icons:ro \
        --env=GTK_THEME=${gtkThemeName} \
        --env=GTK_USE_PORTAL=1 \
        --env=GTK2_RC_FILES=$HOME/.gtkrc-2.0 \
        --env=QT_QPA_PLATFORMTHEME=qt5ct \
        --env=QT_STYLE_OVERRIDE=${lilyaGlass.qtStyleName} \
        --env=XCURSOR_THEME=${cursorThemeName} \
        --env=XCURSOR_SIZE=48

      ${pkgs.flatpak}/bin/flatpak override --user com.tencent.WeChat \
        --env=CHROMIUM_FLAGS=--force-color-profile=srgb \
        --env=ELECTRON_EXTRA_LAUNCH_ARGS=--force-color-profile=srgb \
        --env=QTWEBENGINE_CHROMIUM_FLAGS=--force-color-profile=srgb \
        --env=QT_QPA_PLATFORMTHEME=qt6ct \
        --env=QT_STYLE_OVERRIDE=${lilyaGlass.qtStyleName} \
        --env=GTK_THEME=${gtkThemeName} \
        --env=GTK_USE_PORTAL=1 \
        --env=XCURSOR_THEME=${cursorThemeName} \
        --env=XCURSOR_SIZE=48
    fi
  '';

  # 设置全局环境变量
  home.sessionVariables = {
    GTK_THEME = gtkThemeName;
    GTK_USE_PORTAL = "1";
    GTK2_RC_FILES = "${config.home.homeDirectory}/.gtkrc-2.0";
    QT_QPA_PLATFORMTHEME = "qt5ct";
    QT_STYLE_OVERRIDE = lilyaGlass.qtStyleName;
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    XCURSOR_THEME = cursorThemeName;
    XCURSOR_SIZE = "48";
    PYTHONPATH = "/home/lilya/.local/lib/python3.12/site-packages:\${PYTHONPATH:-}";
  };
}
