{ pkgs, ... }:

let
  fcitxCompatEnv = {
    XMODIFIERS = "@im=fcitx";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "fcitx";
  };
  plasmaOverdoseThemeConfig = pkgs.writeText "plasma-overdose-fcitx5-theme.conf" ''
    [Metadata]
    Name=Plasma Overdose
    Version=1
    Author=lilya
    Description=Plasma Overdose colors for Fcitx5
    ScaleWithDPI=True

    [InputPanel]
    Font="Noto Sans CJK SC 10"
    NormalColor=#4d21cb
    HighlightCandidateColor=#4f22d4
    HighlightColor=#4d21cb
    HighlightBackgroundColor=#bed7fc
    Spacing=3

    [InputPanel/TextMargin]
    Left=10
    Right=10
    Top=6
    Bottom=6

    [InputPanel/Background]
    Color=#fcf0fd

    [InputPanel/Background/Margin]
    Left=2
    Right=2
    Top=2
    Bottom=2

    [InputPanel/Highlight]
    Color=#bed7fc

    [InputPanel/Highlight/Margin]
    Left=10
    Right=10
    Top=7
    Bottom=7

    [Menu]
    Font="Noto Sans CJK SC 10"
    NormalColor=#4d21cb
    Spacing=3

    [Menu/Background]
    Color=#f6e0f8

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
    Color=#bed7fc

    [Menu/Highlight/Margin]
    Left=10
    Right=10
    Top=5
    Bottom=5

    [Menu/Separator]
    Color=#efcfef

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
  plasmaOverdoseTheme = pkgs.runCommand "fcitx5-plasma-overdose-theme" { } ''
    theme_dir="$out/share/fcitx5/themes/plasma-overdose"
    mkdir -p "$theme_dir"
    install -m 0644 ${plasmaOverdoseThemeConfig} "$theme_dir/theme.conf"
    install -m 0644 \
      ${pkgs.fcitx5-rose-pine}/share/fcitx5/themes/rose-pine-dawn/arrow.png \
      "$theme_dir/arrow.png"
    install -m 0644 \
      ${pkgs.fcitx5-rose-pine}/share/fcitx5/themes/rose-pine-dawn/radio.png \
      "$theme_dir/radio.png"
  '';
in
{
  _module.args = {
    inherit fcitxCompatEnv;
  };

  xdg.configFile."fcitx5/conf/classicui.conf".text = ''
    Font="Noto Sans CJK SC 10"
    Theme=plasma-overdose
  '';

  xdg.dataFile."fcitx5/themes/plasma-overdose".source =
    "${plasmaOverdoseTheme}/share/fcitx5/themes/plasma-overdose";
}
