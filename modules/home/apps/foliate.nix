_:

{
  # Foliate 按书籍 CSS 的通用族（serif / sans-serif）选字体；两者都指向文楷 TC，
  # 默认族由 Foliate 设置决定都能用到。书籍自带的具体字体仍优先，除非在 GUI 里开「覆盖字体」。
  dconf.settings."com/github/johnfactotum/Foliate/viewer/font" = {
    serif = "LXGW WenKai TC";
    sans-serif = "LXGW WenKai TC";
    monospace = "LXGW WenKai Mono TC";
  };
}
