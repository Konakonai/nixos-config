{ config, pkgs, ... }:

{
  # Fcitx5 经典界面主题配置 (Catppuccin Latte Lavender)
  xdg.configFile."fcitx5/conf/classicui.conf".text = ''
    Font="Noto Sans CJK SC 10"
    Theme=catppuccin-latte-lavender
  '';

  # Fcitx5 皮肤拷贝并激活圆角边框
  home.file.".local/share/fcitx5/themes/catppuccin-latte-lavender/arrow.png".source =
    "${pkgs.catppuccin-fcitx5}/share/fcitx5/themes/catppuccin-latte-lavender/arrow.png";
  # NOTE: SVG 圆角暂时禁用，xwayland-satellite v0.9+ 修复后恢复
  # home.file.".local/share/fcitx5/themes/catppuccin-latte-lavender/highlight.svg".source =
  #   "${pkgs.catppuccin-fcitx5}/share/fcitx5/themes/catppuccin-latte-lavender/highlight.svg";
  # home.file.".local/share/fcitx5/themes/catppuccin-latte-lavender/panel.svg".source =
  #   "${pkgs.catppuccin-fcitx5}/share/fcitx5/themes/catppuccin-latte-lavender/panel.svg";
  home.file.".local/share/fcitx5/themes/catppuccin-latte-lavender/radio.png".source =
    "${pkgs.catppuccin-fcitx5}/share/fcitx5/themes/catppuccin-latte-lavender/radio.png";

  home.file.".local/share/fcitx5/themes/catppuccin-latte-lavender/theme.conf".text = ''
    # vim: ft=dosini
    [Metadata]
    Name=Catppuccin Latte Lavender
    Version=1.0
    Author=justTOBBI, Isabelinc, Kurome
    Description=Catppuccin Latte Lavender Color Theme
    ScaleWithDPI=True

    [InputPanel]
    Font=Sans 13
    Spacing=3

    NormalColor=#4c4f69
    HighlightCandidateColor=#eff1f5
    HighlightColor=#7287fd
    HighlightBackgroundColor=#ccd0da

    [InputPanel/TextMargin]
    Left=18
    Right=18
    Top=8
    Bottom=8

    [InputPanel/Background]
    Color=#ccd0da
    # Image=panel.svg  # 暂时禁用，xwayland-satellite v0.9+ 修复后恢复

    [InputPanel/Background/Margin]
    Left=3
    Right=3
    Top=3
    Bottom=3

    [InputPanel/Highlight]
    Color=#7287fd
    # Image=highlight.svg  # 暂时禁用，xwayland-satellite v0.9+ 修复后恢复

    [InputPanel/Highlight/Margin]
    Left=6
    Right=6
    Top=4
    Bottom=4

    [Menu]
    Font=Sans 10
    NormalColor=#4c4f69
    Spacing=3

    [Menu/Background]
    Color=#ccd0da

    [Menu/Background/Margin]
    Left=2
    Right=2
    Top=2
    Bottom=2

    [Menu/ContentMargin]
    Left=2
    Right=2
    Top=2
    Bottom=2

    [Menu/Highlight]
    Color=#ea76cb

    [Menu/Highlight/Margin]
    Left=10
    Right=10
    Top=5
    Bottom=5

    [Menu/Separator]
    Color=#eff1f5

    [Menu/CheckBox]
    Image=radio.png

    [Menu/SubMenu]
    Image=arrow.png

    [Menu/TextMargin]
    Left=5
    Right=5
    Top=5
    Bottom=5
  '';
}
