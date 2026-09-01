{ pkgs, ... }:

let
  mpvConf = ''
    # ===== 网盘 / OpenList 流媒体缓存与预读优化 =====
    # 启用大容量内存缓存，大幅减少 WebDAV / 远程挂载下的卡顿与拖拽延迟
    cache=yes
    demuxer-max-bytes=1024MiB
    demuxer-max-back-bytes=512MiB
    demuxer-readahead-secs=120

    # 强制将网络流识别为可精确定位
    force-seekable=yes

    # ===== 记录播放位置与断点续播 =====
    save-position-on-quit=yes

    # ===== 硬件加速解码 =====
    hwdec=auto-safe

    # ===== 字幕与音轨首选语言 =====
    slang=zh,chi,chs,cht,sc,tc,zho,en
    alang=zh,chi,ja,jpn,en
    sub-auto=fuzzy
  '';
in
{
  dconf.settings."io/github/celluloid-player/celluloid" = {
    # 允许 Celluloid 加载 mpv 核心配置文件以应用缓存与解码优化
    mpv-config-enable = true;
  };

  xdg.configFile = {
    # Celluloid 配置与脚本
    "celluloid/mpv.conf".text = mpvConf;
    "celluloid/scripts/autoload.lua".source = "${pkgs.mpvScripts.autoload}/share/mpv/scripts/autoload.lua";
    "celluloid/scripts/memo.lua".source = "${pkgs.mpvScripts.memo}/share/mpv/scripts/memo.lua";
    "celluloid/scripts/autosub.lua".source = "${pkgs.mpvScripts.autosub}/share/mpv/scripts/autosub.lua";

    # 同步为原生 mpv 准备配置与脚本
    "mpv/mpv.conf".text = mpvConf;
    "mpv/scripts/autoload.lua".source = "${pkgs.mpvScripts.autoload}/share/mpv/scripts/autoload.lua";
    "mpv/scripts/memo.lua".source = "${pkgs.mpvScripts.memo}/share/mpv/scripts/memo.lua";
    "mpv/scripts/autosub.lua".source = "${pkgs.mpvScripts.autosub}/share/mpv/scripts/autosub.lua";
  };
}
