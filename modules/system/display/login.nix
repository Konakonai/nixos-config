{ pkgs, inputs, hostProfile, lib, ... }:

let
  lilyaGlass = import ../../glass-settings.nix;
  internalDisplay = hostProfile.display.internal;
  externalDisplay = hostProfile.display.external or null;
  loginWallpaper = hostProfile.display.loginWallpaper or null;
  pos = position: "${builtins.toString position.x} ${builtins.toString position.y}";

  niriPackage = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
  niriSession = "${niriPackage}/bin/niri-session";
  niriLoginCommand = "Niri";
  niriLogin = pkgs.writeShellScriptBin niriLoginCommand ''
    unset GBM_BACKEND __GLX_VENDOR_LIBRARY_NAME

    export NIRI_CONFIG="$HOME/.config/niri/config-intel.kdl"
    exec ${niriSession} "$@"
  '';
  niriLoginPath = lib.getExe niriLogin;
  gtkgreetGtkThemeName = "adw-gtk3";
  gtkgreetGtkThemePackage = pkgs.adw-gtk3;
  gtkgreetFontSize = 14;
  gtkgreetCardWidth = 440;
  gtkgreetCardPadding = 30;
  loginOutputConfig =
    if externalDisplay != null then
      ''
        output * enable scale ${builtins.toString internalDisplay.scale} pos ${pos internalDisplay.position}
        output ${externalDisplay.connector} enable scale ${builtins.toString externalDisplay.scale} pos ${pos externalDisplay.position}
      ''
    else
      ''
        output * enable scale ${builtins.toString internalDisplay.scale} pos ${pos internalDisplay.loginPosition}
      '';
  loginBackgroundCommand =
    if loginWallpaper != null then
      "output * bg ${loginWallpaper} fill"
    else
      "output * bg ${lilyaGlass.palette.base} solid_color";

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
    @define-color border_color #d8dee9;
    @define-color muted_fg_color #4c566a;
    @define-color shadow_color #2e3440;

    window,
    #window {
      background-color: transparent;
      color: @window_fg_color;
      font-family: "${lilyaGlass.fonts.sans}";
      font-size: ${builtins.toString gtkgreetFontSize}px;
    }

    #clock {
      color: @accent_fg_color;
      font-weight: 600;
      margin-bottom: 22px;
      text-shadow: 0 2px 8px alpha(@shadow_color, 0.40);
    }

    box#body {
      background-color: alpha(@card_bg_color, 0.76);
      border: 1px solid alpha(@window_bg_color, 0.52);
      border-radius: ${builtins.toString lilyaGlass.radius.panels}px;
      box-shadow: 0 18px 55px alpha(@shadow_color, 0.24);
      padding: ${builtins.toString gtkgreetCardPadding}px;
      min-width: ${builtins.toString gtkgreetCardWidth}px;
    }

    label {
      color: @card_fg_color;
    }

    button {
      background-color: @accent_bg_color;
      border: 1px solid @accent_bg_color;
      border-radius: ${builtins.toString lilyaGlass.radius.windows}px;
      color: @accent_fg_color;
      min-height: 38px;
      padding: 8px 16px;
    }

    button:hover {
      background-color: #6b8db6;
      border-color: #6b8db6;
    }

    entry,
    #command-selector entry {
      background-color: alpha(@window_bg_color, 0.78);
      border: 1px solid alpha(@border_color, 0.92);
      border-radius: ${builtins.toString lilyaGlass.radius.windows}px;
      color: @window_fg_color;
      min-height: 38px;
      padding: 8px 12px;
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
    ${lib.getExe gtkgreet} -l -s ${gtkgreetCss} -c ${lib.escapeShellArg niriLoginPath}
    ${lib.getExe' pkgs.sway "swaymsg"} exit
  '';

  gtkgreetSwayConfig = pkgs.writeText "gtkgreet-sway-config" ''
    font pango:${lilyaGlass.fonts.sans} 11
    seat seat0 xcursor_theme ${lilyaGlass.cursorThemeName} 48

    ${loginOutputConfig}

    ${loginBackgroundCommand}

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
    package = niriPackage;
  };

  systemd.user.units."niri.service" = {
    overrideStrategy = "asDropin";
    text = ''
      [Service]
      Environment=NIRI_CONFIG=%h/.config/niri/config-intel.kdl
      UnsetEnvironment=GBM_BACKEND __GLX_VENDOR_LIBRARY_NAME
    '';
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
