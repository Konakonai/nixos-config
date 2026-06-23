{ ... }:

{
  services.flatpak = {
    enable = true;

    remotes = [
      {
        name = "flathub";
        location = "https://mirrors.ustc.edu.cn/flathub";
      }
    ];

    packages = [
      "com.qq.QQ"
      "com.tencent.WeChat"
      "org.onlyoffice.desktopeditors"
    ];

    uninstallUnmanaged = true;

    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
  };
}
