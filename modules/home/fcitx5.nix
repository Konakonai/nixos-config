{ lilyaTheme, pkgs, ... }:

let
  inherit (lilyaTheme) palette;

  catppuccinLavenderLightThemeConfig = pkgs.writeText "theme.conf" ''
    [Metadata]
    Name=Catppuccin Lavender Light
    Version=1.0
    Author=Antigravity
    Description=Catppuccin Lavender Light theme for Fcitx5
    ScaleWithDPI=True

    [InputPanel]
    Font="${lilyaTheme.fonts.sans} 11"
    NormalColor=${palette.text}
    HighlightCandidateColor=${palette.onAccent}
    HighlightColor=${palette.accent}
    HighlightBackgroundColor=${palette.surfaceVariant}
    Spacing=4

    [InputPanel/TextMargin]
    Left=14
    Right=14
    Top=8
    Bottom=8

    [InputPanel/Background]
    Color=${palette.surface}
    Image=panel.svg

    [InputPanel/Background/Margin]
    Left=12
    Right=12
    Top=12
    Bottom=12

    [InputPanel/Highlight]
    Color=${palette.accent}
    Image=highlight.svg

    [InputPanel/Highlight/Margin]
    Left=10
    Right=10
    Top=6
    Bottom=6

    [Menu]
    Font="${lilyaTheme.fonts.sans} 10"
    NormalColor=${palette.text}
    Spacing=4

    [Menu/Background]
    Color=${palette.surface}
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
    Color=${palette.accent}
    Image=highlight.svg

    [Menu/Highlight/Margin]
    Left=8
    Right=8
    Top=5
    Bottom=5

    [Menu/Separator]
    Color=${palette.outline}

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
      <rect x="1" y="1" width="46" height="46" rx="12" fill="${palette.surface}" stroke="${palette.outline}" stroke-width="1.5"/>
    </svg>
  '';

  highlightSvg = pkgs.writeText "highlight.svg" ''
    <svg width="48" height="48" version="1.1" xmlns="http://www.w3.org/2000/svg">
      <rect width="48" height="48" rx="8" fill="${palette.accent}"/>
    </svg>
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
  xdg.configFile."fcitx5/conf/classicui.conf".text = ''
    Font="${lilyaTheme.fonts.sans} 11"
    Theme=catppuccin-lavender-light
  '';

  xdg.dataFile."fcitx5/themes/catppuccin-lavender-light".source =
    "${catppuccinLavenderLightTheme}/share/fcitx5/themes/catppuccin-lavender-light";

  # The rime tray icon comes from the icon theme; see pkgs/colloid-icon-theme.nix.
}
