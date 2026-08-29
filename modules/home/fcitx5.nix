{ lilyaTheme, pkgs, ... }:

let
  fcitxCompatEnv = {
    XMODIFIERS = "@im=fcitx";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "fcitx";
  };

  catppuccinLavenderLightThemeConfig = pkgs.writeText "theme.conf" ''
    [Metadata]
    Name=Catppuccin Lavender Light
    Version=1.0
    Author=Antigravity
    Description=Catppuccin Lavender Light theme for Fcitx5
    ScaleWithDPI=True

    [InputPanel]
    Font="${lilyaTheme.fonts.sans} 11"
    NormalColor=#2c243e
    HighlightCandidateColor=#ffffff
    HighlightColor=#7c5cfa
    HighlightBackgroundColor=#f0edfc
    Spacing=4

    [InputPanel/TextMargin]
    Left=14
    Right=14
    Top=8
    Bottom=8

    [InputPanel/Background]
    Color=#faf8ff
    Image=panel.svg

    [InputPanel/Background/Margin]
    Left=12
    Right=12
    Top=12
    Bottom=12

    [InputPanel/Highlight]
    Color=#7c5cfa
    Image=highlight.svg

    [InputPanel/Highlight/Margin]
    Left=10
    Right=10
    Top=6
    Bottom=6

    [Menu]
    Font="${lilyaTheme.fonts.sans} 10"
    NormalColor=#2c243e
    Spacing=4

    [Menu/Background]
    Color=#faf8ff
    Image=panel.svg

    [Menu/Background/Margin]
    Left=8
    Right=8
    Top=8
    Bottom=8

    [Menu/ContentMargin]
    Left=4
    Right=4
    Top=4
    Bottom=4

    [Menu/Highlight]
    Color=#7c5cfa
    Image=highlight.svg

    [Menu/Highlight/Margin]
    Left=8
    Right=8
    Top=5
    Bottom=5

    [Menu/Separator]
    Color=#d8d0f4

    [Menu/CheckBox]
    Image=radio.png

    [Menu/SubMenu]
    Image=arrow.png

    [Menu/TextMargin]
    Left=6
    Right=6
    Top=5
    Bottom=5
  '';

  panelSvg = pkgs.writeText "panel.svg" ''
    <svg width="48" height="48" version="1.1" xmlns="http://www.w3.org/2000/svg">
      <rect x="1" y="1" width="46" height="46" rx="12" fill="#faf8ff" stroke="#d8d0f4" stroke-width="1.5"/>
    </svg>
  '';

  highlightSvg = pkgs.writeText "highlight.svg" ''
    <svg width="48" height="48" version="1.1" xmlns="http://www.w3.org/2000/svg">
      <rect width="48" height="48" rx="8" fill="#7c5cfa"/>
    </svg>
  '';

  # 中州韵的 tray 图标：fcitx5-rime 自带的 hicolor 图标与 Colloid-Light
  # 主题风格不搭，这里把 Colloid-Light 主题内为 fcitx-rime 设计的图标
  # 安装到 fcitx5 用户自定义图标目录（fcitx5 优先于此目录），并注入
  # 用户级 hicolor 兜底，保证托盘主机无论按 SNI IconName 还是按主题
  # 解析都能命中 Colloid-Light 风格的图标。
  colloidRimeIcon = pkgs.runCommand "fcitx5-rime-icon-colloid-light" {
    nativeBuildInputs = [ pkgs.librsvg ];
  } ''
    rime_svg=${pkgs.colloid-icon-theme}/share/icons/${lilyaTheme.iconThemeName}/status/symbolic/fcitx-rime-symbolic.svg

    mkdir -p $out/fcitx5-icons
    cp "$rime_svg" $out/fcitx5-icons/fcitx-rime.svg
    rsvg-convert -w 48 -h 48 -o $out/fcitx5-icons/fcitx-rime.png "$rime_svg"

    mkdir -p $out/hicolor/scalable/apps $out/hicolor/48x48/apps
    cp "$rime_svg" $out/hicolor/scalable/apps/fcitx-rime.svg
    rsvg-convert -w 48 -h 48 -o $out/hicolor/48x48/apps/fcitx-rime.png "$rime_svg"
  '';

  catppuccinLavenderLightTheme = pkgs.runCommand "fcitx5-theme-catppuccin-lavender-light" { } ''
    theme_dir="$out/share/fcitx5/themes/catppuccin-lavender-light"
    mkdir -p "$theme_dir"
    cp ${catppuccinLavenderLightThemeConfig} "$theme_dir/theme.conf"
    cp ${panelSvg} "$theme_dir/panel.svg"
    cp ${highlightSvg} "$theme_dir/highlight.svg"
    cp ${pkgs.catppuccin-fcitx5}/share/fcitx5/themes/catppuccin-latte-lavender/arrow.png "$theme_dir/arrow.png"
    cp ${pkgs.catppuccin-fcitx5}/share/fcitx5/themes/catppuccin-latte-lavender/radio.png "$theme_dir/radio.png"
  '';
in
{
  _module.args = {
    inherit fcitxCompatEnv;
  };

  xdg.configFile."fcitx5/conf/classicui.conf".text = ''
    Font="${lilyaTheme.fonts.sans} 11"
    Theme=catppuccin-lavender-light
  '';

  xdg.dataFile."fcitx5/themes/catppuccin-lavender-light".source =
    "${catppuccinLavenderLightTheme}/share/fcitx5/themes/catppuccin-lavender-light";

  xdg.dataFile."fcitx5/icons/fcitx-rime.svg".source =
    "${colloidRimeIcon}/fcitx5-icons/fcitx-rime.svg";
  xdg.dataFile."fcitx5/icons/fcitx-rime.png".source =
    "${colloidRimeIcon}/fcitx5-icons/fcitx-rime.png";
  xdg.dataFile."icons/hicolor/scalable/apps/fcitx-rime.svg".source =
    "${colloidRimeIcon}/hicolor/scalable/apps/fcitx-rime.svg";
  xdg.dataFile."icons/hicolor/48x48/apps/fcitx-rime.png".source =
    "${colloidRimeIcon}/hicolor/48x48/apps/fcitx-rime.png";
}
