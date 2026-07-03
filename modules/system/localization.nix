{ lib, pkgs, ... }:

let
  fcitx5Configtool = pkgs.qt6Packages.fcitx5-configtool.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      ../../patches/fcitx5-configtool-normal-addon-title-weight.patch
    ];
  });

  fcitx5Addons = with pkgs; [
    fcitx5-gtk
    qt6Packages.fcitx5-qt
    fcitx5Configtool
    fcitx5-nord
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
in
{
  time.timeZone = "Asia/Taipei";
  i18n.defaultLocale = "zh_CN.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.UTF-8";
    LC_IDENTIFICATION = "zh_CN.UTF-8";
    LC_MEASUREMENT = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
    LC_NAME = "zh_CN.UTF-8";
    LC_NUMERIC = "zh_CN.UTF-8";
    LC_PAPER = "zh_CN.UTF-8";
    LC_TELEPHONE = "zh_CN.UTF-8";
    LC_TIME = "zh_CN.UTF-8";
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    package = lib.mkForce fcitx5Package;
    fcitx5 = {
      waylandFrontend = true;
      addons = fcitx5Addons;
    };
  };

  environment.variables.QT_PLUGIN_PATH =
    lib.mkForce [ "${fcitx5Package}/${pkgs.qt6.qtbase.qtPluginPrefix}" ];
}
