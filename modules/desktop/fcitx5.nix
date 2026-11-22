{
  hostProfile,
  lib,
  lilyaTheme,
  pkgs,
  ...
}:

let
  inherit (lilyaTheme) palette;

  fcitx5Configtool = pkgs.qt6Packages.fcitx5-configtool.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      ../../patches/fcitx5-configtool-normal-addon-title-weight.patch
    ];
  });

  fcitx5Addons = with pkgs; [
    fcitx5-gtk
    qt6Packages.fcitx5-qt
    fcitx5Configtool
    catppuccin-fcitx5
    (fcitx5-rime.override {
      rimeDataPkgs = with pkgs; [
        rime-data
        rime-ice
      ];
    })
  ];

  fcitx5Package = pkgs.qt6Packages.fcitx5-with-addons.override {
    addons = fcitx5Addons;
    fcitx5-configtool = fcitx5Configtool;
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
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    package = lib.mkForce fcitx5Package;
    fcitx5 = {
      waylandFrontend = true;
      addons = fcitx5Addons;
    };
  };

  # Prepend the patched Fcitx plugin dir. Do not mkForce the whole
  # QT_PLUGIN_PATH: NixOS already adds the unpatched fcitx5-with-addons path,
  # and other modules/wrappers still need their own plugin entries.
  environment.variables.QT_PLUGIN_PATH = lib.mkBefore [
    "${fcitx5Package}/${pkgs.qt6.qtbase.qtPluginPrefix}"
  ];

  home-manager.users.${hostProfile.user.userName} = {
    xdg.configFile."fcitx5/conf/classicui.conf".text = ''
      Font="${lilyaTheme.fonts.sans} 11"
      Theme=catppuccin-lavender-light
    '';

    xdg.dataFile."fcitx5/themes/catppuccin-lavender-light".source =
      "${catppuccinLavenderLightTheme}/share/fcitx5/themes/catppuccin-lavender-light";

    # The rime tray icon comes from the icon theme; see pkgs/colloid-icon-theme.nix.
  };
}
