{ ... }:

{
  console = {
    # kmscon owns the final virtual console. Avoid configuring a kernel VT
    # bitmap font during initrd boot; with the current kernel this setfont path
    # fails and can briefly expose a non-fullscreen text console under Plymouth.
    earlySetup = false;
    font = null;
    packages = [ ];
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
}
