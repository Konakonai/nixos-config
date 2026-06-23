{ config, pkgs, lib, ... }:

let
  fontMappings = [
    # 无衬线字体 (黑体/Sans-serif) 映射到 Noto Sans
    { from = "微软雅黑"; to = "Noto Sans CJK SC"; }
    { from = "Microsoft YaHei"; to = "Noto Sans CJK SC"; }
    { from = "黑体"; to = "Noto Sans CJK SC"; }
    { from = "SimHei"; to = "Noto Sans CJK SC"; }
    { from = "华文细黑"; to = "Noto Sans CJK SC"; }
    { from = "STXihei"; to = "Noto Sans CJK SC"; }
    { from = "Arial"; to = "Noto Sans CJK SC"; }
    { from = "Calibri"; to = "Noto Sans CJK SC"; }

    # 衬线字体 (宋体/楷体/仿宋/Serif) 映射到 Noto Serif
    { from = "宋体"; to = "Noto Serif CJK SC"; }
    { from = "SimSun"; to = "Noto Serif CJK SC"; }
    { from = "新宋体"; to = "Noto Serif CJK SC"; }
    { from = "NSimSun"; to = "Noto Serif CJK SC"; }
    { from = "仿宋"; to = "Noto Serif CJK SC"; }
    { from = "FangSong"; to = "Noto Serif CJK SC"; }
    { from = "楷体"; to = "Noto Serif CJK SC"; }
    { from = "KaiTi"; to = "Noto Serif CJK SC"; }
    { from = "Times New Roman"; to = "Noto Serif CJK SC"; }
  ];

  fontConfigXml = lib.concatStringsSep "\n" (map (m: ''
      <match target="pattern">
        <test qual="any" name="family"><string>${m.from}</string></test>
        <edit name="family" mode="assign" binding="same"><string>${m.to}</string></edit>
      </match>
  '') fontMappings);

  ccSwitch = pkgs.callPackage ../pkgs/cc-switch-cli/default.nix {};

  mpvWebdavWrapper = pkgs.writers.writePython3Bin "mpv-webdav-wrapper" {
    flakeIgnore = [ "E501" ];
  } ''
    import os
    import subprocess
    import sys
    import urllib.parse
    from pathlib import Path

    MPV = "${lib.getExe pkgs.mpv}"
    CREDENTIALS_PATH = Path(
        os.environ.get(
            "MPV_WEBDAV_CREDENTIALS",
            "~/.config/mpv-webdav/credentials",
        )
    ).expanduser()


    def read_credentials():
        username = os.environ.get("MPV_WEBDAV_USERNAME")
        password = os.environ.get("MPV_WEBDAV_PASSWORD")

        if CREDENTIALS_PATH.exists():
            values = []
            credential_text = CREDENTIALS_PATH.read_text(encoding="utf-8")
            for raw_line in credential_text.splitlines():
                line = raw_line.strip()
                if not line or line.startswith("#"):
                    continue

                if "=" in line:
                    key, value = line.split("=", 1)
                    key = key.strip().lower()
                    value = value.strip().strip("\"'")

                    if key in {"user", "username"}:
                        username = value
                    elif key in {"pass", "password"}:
                        password = value
                else:
                    values.append(line)

            if values:
                username = username or values[0]
            if len(values) > 1:
                password = password or values[1]

        return username or "admin", password


    def quote_credential(value):
        return urllib.parse.quote(value, safe="")


    def convert_gvfs_path(arg, username, password):
        if not password:
            return arg

        parts = arg.split("/gvfs/dav:host=", 1)
        subparts = parts[1].split("/", 1)
        host_port_info = subparts[0]
        remote_path = subparts[1] if len(subparts) > 1 else ""

        host_info = host_port_info.split(",")
        host = host_info[0]
        port = "5244"
        prefix = ""

        for info in host_info[1:]:
            if info.startswith("port="):
                port = info.split("=", 1)[1]
            elif info.startswith("prefix="):
                prefix = urllib.parse.unquote(info.split("=", 1)[1])

        if prefix:
            prefix = "/" + prefix.strip("/")
            full_path = f"{prefix}/{remote_path}"
        elif remote_path.startswith("dav/"):
            full_path = f"/{remote_path}"
        else:
            full_path = f"/dav/{remote_path}"

        encoded_path = "/".join(
            urllib.parse.quote(part)
            for part in full_path.split("/")
        )
        user = quote_credential(username)
        passwd = quote_credential(password)
        return f"http://{user}:{passwd}@{host}:{port}{encoded_path}"


    def convert_dav_url(arg, scheme, username, password):
        parsed = urllib.parse.urlparse(arg)
        netloc = parsed.netloc

        if "@" in netloc:
            user_info, host_port = netloc.split("@", 1)
            if ":" not in user_info:
                if not password:
                    return arg
                user = quote_credential(user_info)
                passwd = quote_credential(password)
                netloc = f"{user}:{passwd}@{host_port}"
        else:
            if not password:
                return arg
            user = quote_credential(username)
            passwd = quote_credential(password)
            netloc = f"{user}:{passwd}@{netloc}"

        return urllib.parse.urlunparse((
            scheme,
            netloc,
            parsed.path,
            parsed.params,
            parsed.query,
            parsed.fragment,
        ))


    def main():
        username, password = read_credentials()
        converted_args = []

        for arg in sys.argv[1:]:
            try:
                if arg.startswith("/run/user/") and "/gvfs/dav:host=" in arg:
                    converted_args.append(
                        convert_gvfs_path(arg, username, password)
                    )
                elif arg.startswith("dav://"):
                    converted_args.append(
                        convert_dav_url(arg, "http", username, password)
                    )
                elif arg.startswith("davs://"):
                    converted_args.append(
                        convert_dav_url(arg, "https", username, password)
                    )
                else:
                    converted_args.append(arg)
            except Exception:
                converted_args.append(arg)

        cmd = [
            MPV,
            "--player-operation-mode=pseudo-gui",
            "--ytdl=no",
            "--sub-auto=no",
            "--force-seekable=yes",
            "--cache=yes",
            "--demuxer-max-bytes=150MiB",
        ] + converted_args

        subprocess.run(cmd, check=False)


    if __name__ == "__main__":
        main()
  '';
in
{
  # XDG 桌面快捷方式 (Desktop Entry)
  xdg.desktopEntries."cc-switch-handler" = {
    name = "CC Switch";
    exec = "${lib.getExe ccSwitch} %u";
    type = "Application";
    terminal = false;
    noDisplay = true;
    mimeType = [ "x-scheme-handler/ccswitch" ];
  };

  xdg.desktopEntries."mpv" = {
    name = "mpv Media Player";
    genericName = "Multimedia player";
    comment = "Play movies and songs";
    exec = "${lib.getExe mpvWebdavWrapper} %U";
    icon = "mpv";
    terminal = false;
    categories = [ "AudioVideo" "Audio" "Video" "Player" "TV" ];
    mimeType = [
      "application/ogg"
      "application/x-mpegurl"
      "application/vnd.apple.mpegurl"
      "audio/aac"
      "audio/flac"
      "audio/mp3"
      "audio/mp4"
      "audio/mpeg"
      "audio/ogg"
      "audio/opus"
      "audio/wav"
      "audio/webm"
      "audio/x-matroska"
      "video/3gp"
      "video/3gpp"
      "video/avi"
      "video/mp2t"
      "video/mp4"
      "video/mpeg"
      "video/ogg"
      "video/quicktime"
      "video/vnd.avi"
      "video/webm"
      "video/x-flv"
      "video/x-matroska"
      "video/x-ms-wmv"
      "video/x-msvideo"
    ];
    settings = {
      TryExec = lib.getExe pkgs.mpv;
      StartupWMClass = "mpv";
      Keywords = "mpv;media;player;video;audio;tv;";
      "X-KDE-Protocols" = "appending,file,ftp,http,https,mms,mpv,rist,rtmp,rtmps,rtmpt,rtmpts,rtp,rtsp,rtsps,sftp,srt,srtp,webdav,webdavs";
    };
  };

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

  xdg.desktopEntries."toggle-power-mode" = {
    name = "切换省电/插电模式";
    genericName = "电源模式切换";
    comment = "在一键省电模式与满血插电模式之间进行切换";
    exec = "toggle-power-mode";
    icon = "battery";
    type = "Application";
    categories = [ "Utility" "System" ];
    terminal = false;
    noDisplay = true;
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
        mode = "light";
        light = "Noctalia Light";
        dark = "Noctalia Light";
      };
    };
  };

  # OnlyOffice 字体别名映射
  xdg.configFile."fontconfig/conf.d/99-simsun-alias.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      ${fontConfigXml}
    </fontconfig>
  '';

  # Scroll 动效配置
  xdg.configFile."scroll/config".text = "include ~/.config/scroll/noctalia\n";
}
