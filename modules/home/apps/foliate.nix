{ lib, ... }:

let
  # 中文书里这些标点要用中文字形：Literata 的省略号贴着基线、破折号偏低，文楷的居中。
  # 连同汉字、假名、全角符号一起交给文楷，其余字符（拉丁字母、数字）用 Literata。
  wenkaiRange = lib.concatStringsSep ", " [
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
in
{
  # 书籍 CSS 只写通用族（serif / sans-serif）时由这里决定字体，两者都指向文楷 TC。
  dconf.settings."com/github/johnfactotum/Foliate/viewer/font" = {
    serif = "LXGW WenKai TC";
    sans-serif = "LXGW WenKai TC";
    monospace = "LXGW WenKai Mono TC";
  };

  # Foliate 的设置每个通用族只能填一个字体，做不到「西文 Literata、中文文楷」，
  # 所以在它启动时读取的用户样式表里按 unicode-range 拼一个复合字体。
  # 中文书（html lang=zh/ja，Foliate 会从元数据补上）用复合字体，标点走文楷；
  # 其他语言直接 Literata 优先，引号等保持西文字形，缺字回退文楷。
  # 规则只挂在 html 上：书籍给元素指定的字体照样生效；开了「覆盖字体」后
  # Foliate 把所有元素 revert 成继承，这里的 !important 让它们继承到复合字体。
  xdg.configFile."com.github.johnfactotum.Foliate/user-stylesheet.css".text = ''
    @font-face {
      font-family: "Reading ZH";
      src: local("Literata");
      font-weight: 100 900;
      font-style: normal;
    }
    @font-face {
      font-family: "Reading ZH";
      src: local("Literata");
      font-weight: 100 900;
      font-style: italic;
    }
    @font-face {
      font-family: "Reading ZH";
      src: local("LXGW WenKai TC");
      font-weight: 100 900;
      font-style: normal;
      unicode-range: ${wenkaiRange};
    }
    @font-face {
      font-family: "Reading ZH";
      src: local("LXGW WenKai TC");
      font-weight: 100 900;
      font-style: italic;
      unicode-range: ${wenkaiRange};
    }

    html:lang(zh), html:lang(ja) {
      font-family: "Reading ZH", "LXGW WenKai TC", serif !important;
    }
    html:not(:lang(zh)):not(:lang(ja)) {
      font-family: "Literata", "LXGW WenKai TC", serif !important;
    }
  '';
}
