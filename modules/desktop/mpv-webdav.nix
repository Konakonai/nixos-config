{ pkgs, lib, ... }:

let
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
    LEGACY_WRAPPER_PATH = Path(
        "~/.local/share/applications/mpv-webdav-wrapper"
    ).expanduser()


    def read_legacy_credentials():
        username = None
        password = None

        if not LEGACY_WRAPPER_PATH.exists():
            return username, password

        for raw_line in LEGACY_WRAPPER_PATH.read_text(
            encoding="utf-8"
        ).splitlines():
            line = raw_line.strip()
            if line.startswith("username ="):
                username = line.split("=", 1)[1].strip().strip("\"'")
            elif line.startswith("password ="):
                password = line.split("=", 1)[1].strip().strip("\"'")

        return username, password


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

        if not password:
            legacy_username, legacy_password = read_legacy_credentials()
            username = username or legacy_username
            password = password or legacy_password

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
}
