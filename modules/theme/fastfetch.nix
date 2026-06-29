{ pkgs, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
  logoSvg = ./assets/nixos-logomark-default-gradient-none.svg;

  logoPng = pkgs.runCommand "fastfetch-nixos-logomark.png" {
    nativeBuildInputs = [ pkgs.resvg ];
  } ''
    resvg -w 640 ${logoSvg} $out
  '';
in
{
  xdg.configFile."fastfetch/config.jsonc".text = builtins.toJSON {
    "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/master/doc/json_schema.json";

    logo = {
      type = "kitty-direct";
      source = "${logoPng}";
      width = 60;
      height = 20;
      preserveAspectRatio = true;
      padding = {
        top = 0;
        right = 4;
      };
    };

    display = {
      separator = "  ";
      brightColor = true;
      color = {
        keys = "blue";
        title = "cyan";
        separator = "blue";
      };
      key = {
        width = 14;
      };
      constants = [
        "fg:${lilyaGlass.palette.text}"
        "accent:${lilyaGlass.palette.accent}"
      ];
    };

    modules = [
      {
        type = "title";
        format = "{user-name-colored}{at-symbol-colored}{host-name-colored}";
      }
      {
        type = "separator";
        string = "┄";
        times = 22;
        outputColor = "blue";
      }
      {
        type = "os";
        key = "╭ OS";
      }
      {
        type = "host";
        key = "├ Host";
      }
      {
        type = "kernel";
        key = "├ Kernel";
      }
      {
        type = "uptime";
        key = "├ Uptime";
      }
      {
        type = "packages";
        key = "╰ Packages";
        combined = false;
        disabled = [ "winget" ];
      }
      {
        type = "separator";
        string = "┄";
        times = 22;
        outputColor = "blue";
      }
      {
        type = "wm";
        key = "╭ WM";
      }
      {
        type = "display";
        key = "├ Displays";
        compactType = "original";
      }
      {
        type = "theme";
        key = "├ Theme";
      }
      {
        type = "terminal";
        key = "├ Terminal";
      }
      {
        type = "shell";
        key = "╰ Shell";
      }
      {
        type = "separator";
        string = "┄";
        times = 22;
        outputColor = "blue";
      }
      {
        type = "cpu";
        key = "╭ CPU";
      }
      {
        type = "gpu";
        key = "├ GPU";
      }
      {
        type = "memory";
        key = "├ Memory";
        format = "{used} / {total} ({percentage})";
      }
      {
        type = "swap";
        key = "├ Swap";
        format = "{used} / {total} ({percentage})";
      }
      {
        type = "disk";
        key = "├ Root";
        folders = "/";
        format = "{size-used} / {size-total} ({size-percentage}) - {filesystem}";
      }
      {
        type = "localip";
        key = "╰ Network";
        compact = true;
      }
    ];
  };
}
