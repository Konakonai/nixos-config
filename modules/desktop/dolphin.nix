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
  xdg.configFile."menus/applications.menu".text = ''
    <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
      "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
    <Menu>
      <Name>Applications</Name>
      <DefaultAppDirs/>
      <DefaultDirectoryDirs/>
      <DefaultMergeDirs/>
      <Include>
        <All/>
      </Include>
    </Menu>
  '';

  home.activation.configureDolphin = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${writeDolphinConfig "General" "GlobalViewProps" "true"}
    ${writeDolphinConfig "IconsMode" "IconSize" "48"}
    ${writeDolphinConfig "IconsMode" "PreviewSize" "64"}
    ${writeDolphinConfig "IconsMode" "UseSystemFont" "false"}
    ${writeDolphinConfig "IconsMode" "ViewFont" "Noto Sans CJK SC,10,-1,5,50,0,0,0,0,0"}
    ${writeDolphinConfig "IconsMode" "TextWidthIndex" "1"}
    ${writeDolphinConfig "IconsMode" "MaximumTextLines" "2"}

    ${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental >/dev/null
  '';
}
