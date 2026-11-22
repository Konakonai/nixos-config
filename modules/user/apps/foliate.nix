{ lib, ... }:

let
  # 中文书里这些标点要用中文字形：Literata 的省略号贴着基线、破折号偏低，文楷的居中。
  # 连同汉字、假名、全角符号一起交给 CJK 字体，其余字符（拉丁字母、数字）用 Literata。
  cjkRange = lib.concatStringsSep ", " [
    "U+00B7" # ·
    "U+2014-2015" # — ―
    "U+2018-2019" # ‘ ’
    "U+201C-201D" # “ ”
    "U+2026" # …
    "U+2E3A-2E3B" # ⸺ ⸻
    "U+2E80-2FFF" # 部首
    "U+3000-30FF" # CJK 标点、假名
    "U+3100-312F" # 注音
    "U+31C0-31FF" # 笔画、假名扩展
    "U+3400-4DBF" # 扩展 A
    "U+4E00-9FFF" # 基本区
    "U+F900-FAFF" # 兼容表意文字
    "U+FE10-FE1F" # 竖排标点
    "U+FE30-FE4F" # CJK 兼容形式
    "U+FF00-FFEF" # 全角
    "U+20000-3134F" # 扩展 B–G
  ];

  # 一个 CSS 字体族：西文用 Literata，cjkRange 内的字符用 cjkFont。
  # 后声明的 face 在 unicode-range 重叠时优先，所以 CJK face 放在后面。
  compositeFamily =
    family: cjkFont:
    lib.concatMapStrings
      (
        {
          font,
          style,
          range,
        }:
        ''
          @font-face {
            font-family: "${family}";
            src: local("${font}");
            font-weight: 100 900;
            font-style: ${style};
            ${lib.optionalString (range != null) "unicode-range: ${range};"}
          }
        ''
      )
      [
        {
          font = "Literata";
          style = "normal";
          range = null;
        }
        {
          font = "Literata";
          style = "italic";
          range = null;
        }
        {
          font = cjkFont;
          style = "normal";
          range = cjkRange;
        }
        {
          font = cjkFont;
          style = "italic";
          range = cjkRange;
        }
      ];

  # 书籍给标题、引文指定宋体 / 明体时，换成和文楷 TC 同为传承字形的源流明体，
  # 而不是系统 fontconfig 别名指向的思源宋体简体字形。只在 Foliate 里生效。
  mingFamilies = [
    "宋体"
    "宋體"
    "SimSun"
    "新宋体"
    "NSimSun"
    "华文宋体"
    "STSong"
    "华文中宋"
    "STZhongsong"
    "Songti SC"
    "Songti TC"
    "方正书宋_GBK"
    "FZShuSong-Z01"
    "思源宋体"
    "Source Han Serif SC"
    "Source Han Serif CN"
    "Source Han Serif TC"
    "Noto Serif CJK SC"
    "Noto Serif CJK TC"
    "明體"
    "新細明體"
    "細明體"
    "PMingLiU"
    "MingLiU"
  ];
in
{
  # 书籍 CSS 只写通用族（serif / sans-serif）时由这里决定字体，两者都指向文楷 TC。
  dconf.settings."com/github/johnfactotum/Foliate/viewer/font" = {
    serif = "LXGW WenKai TC";
    sans-serif = "LXGW WenKai TC";
    monospace = "LXGW WenKai Mono TC";
  };

  # Foliate 的设置每个通用族只能填一个字体，做不到「西文 Literata、中文文楷」，
  # 所以在它启动时读取的用户样式表里按 unicode-range 拼复合字体。
  # 中文书（html lang=zh/ja，Foliate 会从元数据补上）用复合字体，标点走文楷；
  # 其他语言直接 Literata 优先，引号等保持西文字形，缺字回退文楷。
  # 正文规则只是兜底：:where() 把特异度降到 0 且不加 !important，书籍自己给
  # html 或元素指定的字体（含双字体排版）都优先；书没指定时才用复合字体。
  # 开了「覆盖字体」后 Foliate 把所有元素 revert，这时用的是设置里的默认字体。
  xdg.configFile."com.github.johnfactotum.Foliate/user-stylesheet.css".text = ''
    ${compositeFamily "Reading ZH" "LXGW WenKai TC"}
    ${lib.concatMapStrings (family: compositeFamily family "GenRyuMin2 TC") mingFamilies}

    :where(html:lang(zh), html:lang(ja)) {
      font-family: "Reading ZH", "LXGW WenKai TC", serif;
    }
    :where(html:not(:lang(zh)):not(:lang(ja))) {
      font-family: "Literata", "LXGW WenKai TC", serif;
    }
  '';
}
