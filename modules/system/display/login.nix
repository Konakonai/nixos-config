{ pkgs, inputs, hostProfile, lib, ... }:

let
  lilyaGlass = import ../../glass-settings.nix;
  nvidia = hostProfile.graphics.nvidia or { enable = false; };
  internalDisplay = hostProfile.display.internal;
  externalDisplay = hostProfile.display.external or null;
  pos = position: "${builtins.toString position.x} ${builtins.toString position.y}";

  niriBase = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
  niriPatched = pkgs.runCommandLocal "${niriBase.name}-patched-session" {
    passthru = niriBase.passthru or { };
    meta = niriBase.meta or { };
    cargoBuildNoDefaultFeatures = niriBase.cargoBuildNoDefaultFeatures;
    cargoBuildFeatures = niriBase.cargoBuildFeatures;
  } ''
    # niri-session normally imports a small allowlist of environment variables.
    # The desktop session here relies on richer Home Manager/session env, so keep
    # exporting the full current process environment until upstream covers this.
    cp -a ${niriBase} $out
    chmod -R u+w $out
    substituteInPlace $out/bin/niri-session \
      --replace-fail 'systemctl --user import-environment' 'systemctl --user import-environment $(env | cut -d= -f1)'
  '';
  niriSession = "${niriPatched}/bin/niri-session";
  niriLoginCommand = "Niri";
  niriLogin = pkgs.writeShellScriptBin niriLoginCommand ''
    ${if nvidia.enable or false then ''
      if [ "$(cat /sys/class/power_supply/${nvidia.acAdapter}/online 2>/dev/null || echo 0)" = "1" ]; then
        export GBM_BACKEND=nvidia-drm
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        export NIRI_CONFIG="$HOME/.config/niri/config-nvidia.kdl"
      else
        export NIRI_CONFIG="$HOME/.config/niri/config-intel.kdl"
      fi
    '' else ''
      export NIRI_CONFIG="$HOME/.config/niri/config-intel.kdl"
    ''}
    exec ${niriSession} "$@"
  '';
  niriLoginPath = lib.getExe niriLogin;
  gtkgreetGtkThemeName = "adw-gtk3";
  gtkgreetGtkThemePackage = pkgs.adw-gtk3;
  gtkgreetFontSize = 14;
  gtkgreetCardWidth = 420;
  gtkgreetCardPadding = 28;

  gtkgreet = pkgs.gtkgreet.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + ''
      # Give the greeter enough room for high-DPI input widgets.
      substituteInPlace gtkgreet/window.c \
        --replace-fail "size = 32000;" "size = 52000;" \
        --replace-fail "size = 96000;" "size = 128000;"
      # Show friendly command names while keeping the full command as selected value.
      substituteInPlace gtkgreet/config.c \
        --replace-fail '#include <stdio.h>' '#include <stdio.h>
#include <string.h>' \
        --replace-fail 'int config_update_command_selector(GtkWidget *combobox) {' 'static const char *display_command(const char *command) {
    const char *base = strrchr(command, '"'"'/'"'"');
    return base == NULL ? command : base + 1;
}

int config_update_command_selector(GtkWidget *combobox) {' \
        --replace-fail 'gtk_combo_box_text_append((GtkComboBoxText*)combobox, NULL, gtkgreet->command);' 'gtk_combo_box_text_append((GtkComboBoxText*)combobox, gtkgreet->command, display_command(gtkgreet->command));' \
        --replace-fail 'gtk_combo_box_text_append((GtkComboBoxText*)combobox, NULL, buffer);' 'gtk_combo_box_text_append((GtkComboBoxText*)combobox, buffer, display_command(buffer));'
      substituteInPlace gtkgreet/actions.c \
        --replace-fail 'gtkgreet->selected_command = strdup(gtk_combo_box_text_get_active_text((GtkComboBoxText*)ctx->command_selector));' 'const gchar *command_id = gtk_combo_box_get_active_id((GtkComboBox*)ctx->command_selector);
            gtkgreet->selected_command = strdup(command_id == NULL ? gtk_combo_box_text_get_active_text((GtkComboBoxText*)ctx->command_selector) : command_id);'
    '';
  });

  gtkgreetCss = pkgs.writeText "gtkgreet.css" ''
    @define-color accent_color #5e81ac;
    @define-color accent_bg_color #5e81ac;
    @define-color accent_fg_color #eceff4;
    @define-color window_bg_color #eceff4;
    @define-color window_fg_color #2e3440;
    @define-color card_bg_color #e5e9f0;
    @define-color card_fg_color #2e3440;
    @define-color border_color #cdd8e4;
    @define-color muted_fg_color #4c566a;

    window,
    #window {
      background-color: @window_bg_color;
      color: @window_fg_color;
      font-family: "${lilyaGlass.fonts.sans}";
      font-size: ${builtins.toString gtkgreetFontSize}px;
    }

    #clock {
      color: @accent_color;
      font-weight: 600;
      margin-bottom: 24px;
      text-shadow: none;
    }

    box#body {
      background-color: alpha(@card_bg_color, 0.84);
      border: 1px solid @border_color;
      border-radius: 10px;
      box-shadow: 0 12px 30px alpha(#3b4252, 0.10);
      padding: ${builtins.toString gtkgreetCardPadding}px;
      min-width: ${builtins.toString gtkgreetCardWidth}px;
    }

    label {
      color: @card_fg_color;
    }

    button {
      background-color: @accent_bg_color;
      border: 1px solid @accent_bg_color;
      border-radius: 10px;
      color: @accent_fg_color;
      padding: 8px 16px;
    }

    button:hover {
      background-color: #6b8db6;
      border-color: #6b8db6;
    }

    entry,
    #command-selector entry {
      background-color: alpha(@window_bg_color, 0.72);
      border: 1px solid @border_color;
      border-radius: 10px;
      color: @window_fg_color;
      padding: 8px 10px;
    }

    entry:focus,
    #command-selector entry:focus {
      border-color: @accent_color;
      box-shadow: 0 0 0 2px alpha(@accent_color, 0.18);
    }

    #command-selector {
      color: @muted_fg_color;
    }
  '';

  gtkgreetCommand = pkgs.writeShellScript "gtkgreet-command" ''
    ${if externalDisplay != null then ''
      external="$(${lib.getExe' pkgs.sway "swaymsg"} -t get_outputs | ${lib.getExe pkgs.jq} -r \
        --arg connector ${lib.escapeShellArg externalDisplay.connector} \
        --arg make ${lib.escapeShellArg externalDisplay.make} \
        --arg model ${lib.escapeShellArg externalDisplay.model} \
        --arg serial ${lib.escapeShellArg externalDisplay.serial} \
        'first(.[] | select(.active and (.name == $connector or (.make == $make and .model == $model and .serial == $serial))) | .name) // ""' \
        2>/dev/null || true)"

      if [ -n "$external" ]; then
        ${lib.getExe' pkgs.sway "swaymsg"} output "$external" enable scale ${builtins.toString externalDisplay.scale} pos ${pos externalDisplay.loginPosition} >/dev/null 2>&1 || true
        ${lib.getExe' pkgs.sway "swaymsg"} output ${lib.escapeShellArg internalDisplay.connector} disable >/dev/null 2>&1 || true
      else
        ${lib.getExe' pkgs.sway "swaymsg"} output ${lib.escapeShellArg internalDisplay.connector} enable scale ${builtins.toString internalDisplay.scale} pos ${pos internalDisplay.loginPosition} >/dev/null 2>&1 || true
      fi
    '' else ''
      ${lib.getExe' pkgs.sway "swaymsg"} output ${lib.escapeShellArg internalDisplay.connector} enable scale ${builtins.toString internalDisplay.scale} pos ${pos internalDisplay.loginPosition} >/dev/null 2>&1 || true
    ''}

    ${lib.getExe gtkgreet} -l -s ${gtkgreetCss} -c ${lib.escapeShellArg niriLoginPath}
    ${lib.getExe' pkgs.sway "swaymsg"} exit
  '';

  gtkgreetSwayConfig = pkgs.writeText "gtkgreet-sway-config" ''
    font pango:${lilyaGlass.fonts.sans} 11
    seat seat0 xcursor_theme ${lilyaGlass.cursorThemeName} 48

    output * bg ${lilyaGlass.palette.base} solid_color

    exec ${gtkgreetCommand}
  '';

  gtkgreetSession = pkgs.writeShellScript "gtkgreet-session" ''
    export GTK_THEME=${gtkgreetGtkThemeName}
    export XCURSOR_THEME=${lib.escapeShellArg lilyaGlass.cursorThemeName}
    export XCURSOR_SIZE=48
    export XDG_DATA_DIRS=${gtkgreetGtkThemePackage}/share:${pkgs.colloid-icon-theme}/share:${pkgs.nordzy-cursor-theme}/share:''${XDG_DATA_DIRS:-/run/current-system/sw/share}

    exec ${pkgs.dbus}/bin/dbus-run-session ${lib.getExe pkgs.sway} --unsupported-gpu --config ${gtkgreetSwayConfig}
  '';
in
{
  programs.niri = {
    enable = true;
    package = niriPatched;
  };

  services.greetd = {
    enable = true;
    useTextGreeter = false;
    settings.default_session = {
      command = "${gtkgreetSession}";
      user = "greeter";
    };
  };

  environment.etc."greetd/environments".text = ''
    ${niriLoginPath}
  '';
}
