{ lilyaGlass, pkgs, ... }:

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
    Font="${lilyaGlass.fonts.sans} 10"
    NormalColor=${lilyaGlass.palette.text}
    HighlightCandidateColor=${lilyaGlass.palette.onHover}
    HighlightColor=${lilyaGlass.palette.accent}
    HighlightBackgroundColor=${lilyaGlass.palette.hover}
    Spacing=3

    [InputPanel/TextMargin]
    Left=10
    Right=10
    Top=6
    Bottom=6

    [InputPanel/Background]
    Color=${lilyaGlass.palette.base}

    [InputPanel/Background/Margin]
    Left=2
    Right=2
    Top=2
    Bottom=2

    [InputPanel/Highlight]
    Color=${lilyaGlass.palette.hover}

    [InputPanel/Highlight/Margin]
    Left=10
    Right=10
    Top=7
    Bottom=7

    [Menu]
    Font="${lilyaGlass.fonts.sans} 10"
    NormalColor=${lilyaGlass.palette.text}
    Spacing=3

    [Menu/Background]
    Color=${lilyaGlass.palette.mantle}

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
    Color=${lilyaGlass.palette.hover}

    [Menu/Highlight/Margin]
    Left=10
    Right=10
    Top=5
    Bottom=5

    [Menu/Separator]
    Color=${lilyaGlass.palette.crust}

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
    Font="${lilyaGlass.fonts.sans} 10"
    Theme=plasma-overdose
  '';

  xdg.dataFile."fcitx5/themes/plasma-overdose".source =
    "${plasmaOverdoseTheme}/share/fcitx5/themes/plasma-overdose";
}
