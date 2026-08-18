{ config, lib, lilyaGlass, pkgs, ... }:

let
  kdeGlobals = "${config.xdg.configHome}/kdeglobals";
  kwinConfig = "${config.xdg.configHome}/kwinrc";
  plasmaConfig = "${config.xdg.configHome}/plasmarc";
  powerDevilConfig = "${config.xdg.configHome}/powerdevilrc";
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

  home.activation.configurePlasmaAppearance = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${writeKdeConfig kdeGlobals "General" "ColorScheme" "BreezeLight"}
    ${writeKdeConfig kdeGlobals "General" "font" uiFont}
    ${writeKdeConfig kdeGlobals "General" "fixed" fixedFont}
    ${writeKdeConfig kdeGlobals "General" "menuFont" uiFont}
    ${writeKdeConfig kdeGlobals "General" "toolBarFont" uiFont}
    ${writeKdeConfig kdeGlobals "General" "smallestReadableFont" uiFont}
    ${writeKdeConfig kdeGlobals "WM" "activeFont" uiFont}
    ${writeKdeConfig kdeGlobals "WM" "inactiveFont" uiFont}
    ${writeKdeConfig kdeGlobals "Icons" "Theme" lilyaGlass.iconThemeName}
    ${writeKdeConfig kdeGlobals "KDE" "LookAndFeelPackage" "org.kde.breeze.desktop"}
    ${writeKdeConfig kdeGlobals "KDE" "widgetStyle" "klassy"}
    ${writeKdeConfig plasmaConfig "Theme" "name" "kite-light"}
    ${writeKdeConfig kwinConfig "org.kde.kdecoration2" "library" "org.kde.klassy"}
    ${writeKdeConfig kwinConfig "org.kde.kdecoration2" "theme" "klassy"}
    ${writeKdeConfig kwinConfig "org.kde.kdecoration2" "ButtonsOnLeft" "XIA"}
    ${writeKdeConfig kwinConfig "org.kde.kdecoration2" "ButtonsOnRight" ""}
  '';

  home.packages = [
    pkgs.klassy
  ];

  xdg.configFile."klassy/klassyrc".text = ''
    [Common]
    ShadowColor=0,0,0
    ShadowSize=ShadowLarge
    ShadowStrength=255

    [Style]
    AnimationsEnabled=true
    ButtonCornerRadius=10
    CornerRadius=10
    DrawToolBarShadow=false
    DrawWidgetShadow=true
    MatchTitleBarToApplicationColor=true
    ShadowSize=ShadowLarge
    ShadowStrength=255
    UnisonHovering=true
    WindowCornerRadius=12

    [Windeco]
    ActiveTitleBarOpacity=100
    AdjustBackgroundColorOnPoorContrastActive=true
    AdjustBackgroundColorOnPoorContrastInactive=true
    AnimationsEnabled=true
    AnimationsSpeedRelativeSystem=0
    ApplyOpacityToHeader=true
    BlurTransparentTitleBars=true
    BoldButtonIcons=BoldIconsBold
    BoldTitle=false
    ButtonBackgroundColorsActive=AccentTrafficLights
    ButtonBackgroundColorsInactive=AccentTrafficLights
    ButtonBackgroundOpacityActive=85
    ButtonBackgroundOpacityInactive=50
    ButtonColorsInactiveSameHoverPress=true
    ButtonCornerRadius=SameAsWindow
    ButtonCustomCornerRadius=1
    ButtonIconColorsActive=TitleBarText
    ButtonIconColorsInactive=TitleBarText
    ButtonIconOpacityActive=100
    ButtonIconOpacityInactive=100
    ButtonIconStyle=StyleArk
    ButtonShape=ShapeSmallCircle
    ButtonSpacingLeft=10
    ButtonSpacingRight=10
    ButtonStateCheckedActive=Press
    ButtonStateCheckedInactive=Press
    CloseButtonIconColorActive=AsSelected
    CloseButtonIconColorInactive=AsSelected
    DrawBackgroundGradient=false
    DrawBorderOnMaximizedWindows=false
    DrawTitleBarSeparator=false
    ForceColorizeSystemIcons=true
    IconSize=IconMedium
    InactiveTitleBarOpacity=100
    KwinBorderSize=None
    KwinButtonsOnLeft=XIA
    KwinButtonsOnRight=
    MatchTitleBarToApplicationColor=true
    NegativeCloseBackgroundHoverPressActive=false
    NegativeCloseBackgroundHoverPressInactive=false
    OpaqueMaximizedTitleBars=false
    OverrideActiveTitleBarOpacity=false
    OverrideInactiveTitleBarOpacity=false
    RoundAllCornersWhenNoBorders=true
    ScaleBackgroundPercent=100
    ScaleTouchMode=150
    ShadowColor=0,0,0
    ShadowSize=ShadowLarge
    ShadowStrength=255
    ShowBackgroundNormallyActive=true
    ShowBackgroundNormallyInactive=true
    ShowBackgroundOnHoverActive=true
    ShowBackgroundOnHoverInactive=true
    ShowBackgroundOnPressActive=true
    ShowBackgroundOnPressInactive=true
    ShowCloseBackgroundNormallyActive=true
    ShowCloseBackgroundNormallyInactive=true
    ShowCloseBackgroundOnHoverActive=true
    ShowCloseBackgroundOnHoverInactive=true
    ShowCloseBackgroundOnPressActive=true
    ShowCloseBackgroundOnPressInactive=true
    ShowCloseIconNormallyActive=false
    ShowCloseIconNormallyInactive=false
    ShowCloseIconOnHoverActive=true
    ShowCloseIconOnHoverInactive=true
    ShowCloseIconOnPressActive=true
    ShowCloseIconOnPressInactive=true
    ShowCloseOutlineNormallyActive=true
    ShowCloseOutlineNormallyInactive=true
    ShowCloseOutlineOnHoverActive=true
    ShowCloseOutlineOnHoverInactive=true
    ShowCloseOutlineOnPressActive=true
    ShowCloseOutlineOnPressInactive=true
    ShowIconNormallyActive=false
    ShowIconNormallyInactive=false
    ShowIconOnHoverActive=true
    ShowIconOnHoverInactive=true
    ShowIconOnPressActive=true
    ShowIconOnPressInactive=true
    ShowOutlineNormallyActive=true
    ShowOutlineNormallyInactive=true
    ShowOutlineOnHoverActive=true
    ShowOutlineOnHoverInactive=true
    ShowOutlineOnPressActive=true
    ShowOutlineOnPressInactive=true
    SystemIconSize=SystemIcon18
    TitleAlignment=AlignCenterFullWidth
    TitleBarBottomMargin=7
    TitleBarLeftMargin=10
    TitleBarRightMargin=10
    TitleBarTopMargin=7
    TitleSidePadding=4
    UnisonHovering=true
    UseHoverAccentActive=false
    UseHoverAccentInactive=false
    UseTitleBarColorForAllBorders=true
    WindowCornerRadius=12
    WindowOutlineStyleActive=WindowOutlineContrast
    WindowOutlineStyleInactive=WindowOutlineContrast
    WindowOutlineThickness=1
  '';

  xdg.configFile."klassyrc".text = config.xdg.configFile."klassy/klassyrc".text;

  home.activation.configurePlasmaShortcuts = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    # Keep Plasma's Meta+L lock screen and Meta+Alt+Arrow focus navigation.
    ${writeKdeConfig shortcutsConfig "kwin" "Overview" "Meta+O\tMeta+W,Meta+W,显示/隐藏桌面总览"}
    ${writeKdeConfig shortcutsConfig "kwin" "Window Close" "Meta+Q,Alt+F4,关闭窗口"}
    ${writeKdeConfig shortcutsConfig "kwin" "Window Maximize" "Meta+F,Meta+PgUp,最大化窗口"}
    ${writeKdeConfig shortcutsConfig "kwin" "Window Fullscreen" "Meta+Shift+F,none,全屏显示窗口"}
    ${writeKdeConfig shortcutsConfig "plasmashell" "activate application launcher" "Meta+Space\tMeta\tAlt+F1,Meta\tAlt+F1,激活应用程序启动器"}
    ${writeKdeConfig shortcutsConfig "plasmashell" "manage activities" "none,Meta+Q,显示活动切换器"}
  '';

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
    lib.hm.dag.entryAfter [ "configureDolphin" "configurePlasmaAppearance" ] ''
      ${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental >/dev/null
    '';
}
