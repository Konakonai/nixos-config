{ config, pkgs, ... }:

{
  # XDG 桌面快捷方式 (Desktop Entry)
  xdg.desktopEntries."antigravity" = {
    name = "Antigravity";
    exec = "antigravity %F";
    icon = "antigravity";
    type = "Application";
    categories = [ "Utility" ];
    terminal = false;
    mimeType = [ "x-scheme-handler/antigravity" ];
  };

  xdg.desktopEntries."dev.zed.Zed" = {
    name = "Zed";
    genericName = "Text Editor";
    comment = "A high-performance, multiplayer code editor.";
    exec = "zeditor %U";
    icon = "zed";
    type = "Application";
    categories = [ "Utility" "TextEditor" "Development" "IDE" ];
    mimeType = [
      "text/plain"
      "application/x-zerosize"
      "x-scheme-handler/zed"
      "text/markdown"
      "application/json"
      "application/x-toml"
      "application/x-yaml"
      "text/x-python"
      "text/x-shellscript"
    ];
    settings = {
      StartupNotify = "true";
    };
    actions = {
      "NewWorkspace" = {
        exec = "zeditor --new %U";
        name = "Open a new workspace";
      };
    };
  };

  xdg.desktopEntries."yazi" = {
    name = "Yazi";
    genericName = "File Manager";
    exec = "kitty -e yazi %u";
    icon = "yazi";
    terminal = false;
    categories = [ "Utility" "FileTools" "System" "FileManager" ];
    mimeType = [ "inode/directory" ];
  };

  xdg.desktopEntries."nemo" = {
    name = "Files";
    genericName = "File Manager";
    exec = "nemo %U";
    icon = "system-file-manager";
    terminal = false;
    categories = [ "Utility" "FileTools" "System" "FileManager" ];
    mimeType = [ "inode/directory" ];
  };

  # 默认应用关联 (MIME Association)
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/antigravity" = "antigravity.desktop";
      "x-scheme-handler/ccswitch" = "cc-switch-handler.desktop";
      "x-scheme-handler/http" = "zen-beta.desktop";
      "x-scheme-handler/https" = "zen-beta.desktop";
      "x-scheme-handler/chrome" = "zen-beta.desktop";
      "text/html" = "zen-beta.desktop";
      "application/x-extension-htm" = "zen-beta.desktop";
      "application/x-extension-html" = "zen-beta.desktop";
      "application/x-extension-shtml" = "zen-beta.desktop";
      "application/xhtml+xml" = "zen-beta.desktop";
      "application/x-extension-xhtml" = "zen-beta.desktop";
      "application/x-extension-xht" = "zen-beta.desktop";
      "application/pdf" = "zen-beta.desktop";
      "inode/directory" = "nemo.desktop";

      # 视频关联 (VLC)
      "video/mp4" = "vlc.desktop";
      "video/x-matroska" = "vlc.desktop";
      "video/webm" = "vlc.desktop";
      "video/mpeg" = "vlc.desktop";
      "video/avi" = "vlc.desktop";
      "video/quicktime" = "vlc.desktop";
      "video/x-flv" = "vlc.desktop";
      "video/3gp" = "vlc.desktop";
      "video/3gpp" = "vlc.desktop";
      "video/x-ms-wmv" = "vlc.desktop";
      "video/x-msvideo" = "vlc.desktop";

      # 归类解压缩工具关联 (File Roller)
      "application/zip" = "org.gnome.FileRoller.desktop";
      "application/x-tar" = "org.gnome.FileRoller.desktop";
      "application/x-gzip" = "org.gnome.FileRoller.desktop";
      "application/x-bzip2" = "org.gnome.FileRoller.desktop";
      "application/x-7z-compressed" = "org.gnome.FileRoller.desktop";
      "application/x-rar" = "org.gnome.FileRoller.desktop";
      "application/x-xz" = "org.gnome.FileRoller.desktop";

      "text/plain" = "dev.zed.Zed.desktop";
      "text/markdown" = "dev.zed.Zed.desktop";
      "application/json" = "dev.zed.Zed.desktop";
      "application/x-yaml" = "dev.zed.Zed.desktop";
      "application/x-toml" = "dev.zed.Zed.desktop";
      "text/x-python" = "dev.zed.Zed.desktop";
      "text/x-shellscript" = "dev.zed.Zed.desktop";

      # OnlyOffice 关联
      "application/msword" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.openxmlformats-officedocument.wordprocessingml.template" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-word.document.macroEnabled.12" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-word.template.macroEnabled.12" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-excel" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.openxmlformats-officedocument.spreadsheetml.template" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-excel.sheet.macroEnabled.12" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-excel.template.macroEnabled.12" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-excel.addin.macroEnabled.12" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-excel.sheet.binary.macroEnabled.12" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-powerpoint" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.openxmlformats-officedocument.presentationml.presentation" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.openxmlformats-officedocument.presentationml.template" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.openxmlformats-officedocument.presentationml.slideshow" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-powerpoint.addin.macroEnabled.12" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-powerpoint.presentation.macroEnabled.12" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-powerpoint.template.macroEnabled.12" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.ms-powerpoint.slideshow.macroEnabled.12" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.oasis.opendocument.text" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.oasis.opendocument.spreadsheet" = "org.onlyoffice.desktopeditors.desktop";
      "application/vnd.oasis.opendocument.presentation" = "org.onlyoffice.desktopeditors.desktop";
      "application/rtf" = "org.onlyoffice.desktopeditors.desktop";
      "text/csv" = "org.onlyoffice.desktopeditors.desktop";
    };
  };

  # Zed 声明式设置
  programs.zed-editor = {
    enable = true;
    userSettings = {
      cli_default_open_behavior = "existing_window";
      proxy = "";
      agent = {
        default_model = {
          provider = "opencode";
          model = "go/kimi-k2.5";
          enable_thinking = false;
        };
        favorite_models = [];
        model_parameters = [];
      };
      session = {
        trust_all_worktrees = true;
      };
      ui_font_family = "JetBrains Maple Mono";
      buffer_font_family = "JetBrains Maple Mono";
      ui_font_size = 16;
      buffer_font_size = 15;
      theme = {
        mode = "system";
        light = "Noctalia Light";
        dark = "Noctalia Dark Transparent";
      };
    };
  };

  # OnlyOffice 字体别名映射
  xdg.configFile."fontconfig/conf.d/99-simsun-alias.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <!-- 无衬线字体 (黑体/Sans-serif) 映射到 Noto Sans -->
      <match target="pattern">
        <test qual="any" name="family"><string>微软雅黑</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Sans CJK SC</string></edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>Microsoft YaHei</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Sans CJK SC</string></edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>黑体</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Sans CJK SC</string></edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>SimHei</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Sans CJK SC</string></edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>华文细黑</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Sans CJK SC</string></edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>STXihei</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Sans CJK SC</string></edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>Arial</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Sans CJK SC</string></edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>Calibri</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Sans CJK SC</string></edit>
      </match>

      <!-- 衬线字体 (宋体/楷体/仿宋/Serif) 映射到 Noto Serif -->
      <match target="pattern">
        <test qual="any" name="family"><string>宋体</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Serif CJK SC</string></edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>SimSun</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Serif CJK SC</string></edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>新宋体</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Serif CJK SC</string></edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>NSimSun</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Serif CJK SC</string></edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>仿宋</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Serif CJK SC</string></edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>FangSong</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Serif CJK SC</string></edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>楷体</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Serif CJK SC</string></edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>KaiTi</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Serif CJK SC</string></edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>Times New Roman</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Serif CJK SC</string></edit>
      </match>
    </fontconfig>
  '';

  # Scroll 动效配置
  xdg.configFile."scroll/config".text = "include ~/.config/scroll/noctalia\n";
}
