{ lilyaTheme, ... }:

{
  console = {
    # kmscon owns the final virtual console. Avoid configuring a kernel VT
    # bitmap font during initrd boot; with the current kernel this setfont path
    # fails and can briefly expose a non-fullscreen text console under Plymouth.
    earlySetup = false;
    font = null;
    packages = [ ];
    # kmscon ignores these. They become vt.default_* kernel parameters and
    # theme the kernel console shown before kmscon takes over (early boot,
    # emergency shell).
    colors = [
      "2e3440"
      "bf616a"
      "a3be8c"
      "ebcb8b"
      "81a1c1"
      "b48ead"
      "88c0d0"
      "e5e9f0"
      "4c566a"
      "bf616a"
      "a3be8c"
      "ebcb8b"
      "81a1c1"
      "b48ead"
      "8fbcbb"
      "eceff4"
    ];
  };

  services.kmscon = {
    enable = true;
    useXkbConfig = true;
    config = {
      # Keep virtual consoles on the boot GPU so kmscon cannot hold the
      # discrete NVIDIA GPU awake after switching to a graphical session.
      gpus = "primary";
      hwaccel = true;
      font-name = lilyaTheme.fonts.sans;
      font-size = 16;
      multi-monitor = "largest";
      term = "xterm-256color";
    };
  };
}
