{ config, lib, pkgs, ... }:

let
  dolphinConfig = "${config.xdg.configHome}/dolphinrc";
  writeDolphinConfig = group: key: value: ''
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file ${lib.escapeShellArg dolphinConfig} \
      --group ${lib.escapeShellArg group} \
      --key ${lib.escapeShellArg key} \
      ${lib.escapeShellArg value}
  '';
in
{
  home.activation.configureDolphin = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${writeDolphinConfig "General" "GlobalViewProps" "true"}
    ${writeDolphinConfig "IconsMode" "IconSize" "48"}
    ${writeDolphinConfig "IconsMode" "PreviewSize" "64"}
    ${writeDolphinConfig "IconsMode" "TextWidthIndex" "0"}
    ${writeDolphinConfig "IconsMode" "MaximumTextLines" "2"}

    ${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental >/dev/null
  '';
}
