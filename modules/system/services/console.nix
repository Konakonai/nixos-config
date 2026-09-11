{ ... }:

{
  services.kmscon = {
    enable = true;
    useXkbConfig = true;
    config = {
      hwaccel = true;
      font-name = "Noto Sans CJK SC";
      font-size = 16;
      multi-monitor = "largest";
      term = "xterm-256color";
    };
  };
}
