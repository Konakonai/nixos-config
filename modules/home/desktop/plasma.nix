{ config, lib, lilyaGlass, pkgs, ... }:

let
  kdeGlobals = "${config.xdg.configHome}/kdeglobals";
  kwinConfig = "${config.xdg.configHome}/kwinrc";
  plasmaConfig = "${config.xdg.configHome}/plasmarc";
  shortcutsConfig = "${config.xdg.configHome}/kglobalshortcutsrc";
  uiFont = "${lilyaGlass.fonts.sans},${builtins.toString lilyaGlass.fonts.size},-1,5,50,0,0,0,0,0";
  fixedFont = "${lilyaGlass.fonts.mono},${builtins.toString lilyaGlass.fonts.size},-1,5,50,0,0,0,0,0";
  writeKdeConfig = file: group: key: value: ''
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file ${lib.escapeShellArg file} \
      --group ${lib.escapeShellArg group} \
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

  home.activation.configurePlasmaAppearance = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${writeKdeConfig kdeGlobals "General" "ColorScheme" "PlasmaOverdose"}
    ${writeKdeConfig kdeGlobals "General" "font" uiFont}
    ${writeKdeConfig kdeGlobals "General" "fixed" fixedFont}
    ${writeKdeConfig kdeGlobals "General" "menuFont" uiFont}
    ${writeKdeConfig kdeGlobals "General" "toolBarFont" uiFont}
    ${writeKdeConfig kdeGlobals "General" "smallestReadableFont" uiFont}
    ${writeKdeConfig kdeGlobals "WM" "activeFont" uiFont}
    ${writeKdeConfig kdeGlobals "WM" "inactiveFont" uiFont}
    ${writeKdeConfig kdeGlobals "Icons" "Theme" lilyaGlass.iconThemeName}
    ${writeKdeConfig kdeGlobals "KDE" "LookAndFeelPackage" "Plasma-Overdose"}
    ${writeKdeConfig kdeGlobals "KDE" "widgetStyle" "Windows"}
    ${writeKdeConfig plasmaConfig "Theme" "name" "Plasma-Overdose"}
    ${writeKdeConfig kwinConfig "org.kde.kdecoration2" "library" "org.kde.kwin.aurorae"}
    ${writeKdeConfig kwinConfig "org.kde.kdecoration2" "theme" "Plasma-Overdose-KWinDeco"}

    ${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental >/dev/null
  '';

  home.activation.configurePlasmaShortcuts = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    # Keep Plasma's Meta+L lock screen and Meta+Alt+Arrow focus navigation.
    ${writeKdeConfig shortcutsConfig "kwin" "Overview" "Meta+O\tMeta+W,Meta+W,显示/隐藏桌面总览"}
    ${writeKdeConfig shortcutsConfig "kwin" "Window Close" "Meta+Q,Alt+F4,关闭窗口"}
    ${writeKdeConfig shortcutsConfig "kwin" "Window Maximize" "Meta+F,Meta+PgUp,最大化窗口"}
    ${writeKdeConfig shortcutsConfig "kwin" "Window Fullscreen" "Meta+Shift+F,none,全屏显示窗口"}
    ${writeKdeConfig shortcutsConfig "plasmashell" "activate application launcher" "Meta+Space\tMeta\tAlt+F1,Meta\tAlt+F1,激活应用程序启动器"}
    ${writeKdeConfig shortcutsConfig "plasmashell" "manage activities" "none,Meta+Q,显示活动切换器"}
  '';
}
