{ ... }:

{
  services.kmscon = {
    enable = true;
    useXkbConfig = true;
    config = {
      # Keep virtual consoles on the boot GPU so kmscon cannot hold the
      # discrete NVIDIA GPU awake after switching to a graphical session.
      gpus = "primary";
      hwaccel = true;
      font-name = "Noto Sans CJK SC";
      font-size = 16;
      multi-monitor = "largest";
      term = "xterm-256color";
    };
  };
}
