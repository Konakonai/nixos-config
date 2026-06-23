{ lib, ... }:

let
  fontMappings = [
    { from = "微软雅黑"; to = "Noto Sans CJK SC"; }
    { from = "Microsoft YaHei"; to = "Noto Sans CJK SC"; }
    { from = "黑体"; to = "Noto Sans CJK SC"; }
    { from = "SimHei"; to = "Noto Sans CJK SC"; }
    { from = "华文细黑"; to = "Noto Sans CJK SC"; }
    { from = "STXihei"; to = "Noto Sans CJK SC"; }
    { from = "Arial"; to = "Noto Sans CJK SC"; }
    { from = "Calibri"; to = "Noto Sans CJK SC"; }

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
in
{
  xdg.configFile."fontconfig/conf.d/99-simsun-alias.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      ${fontConfigXml}
    </fontconfig>
  '';
}
