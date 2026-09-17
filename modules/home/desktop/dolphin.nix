{ lilyaTheme, ... }:

let
  qtFont = family: size: "${family},${toString size},-1,5,50,0,0,0,0,0";
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

  # plasma-manager writes only these keys; everything else in the files stays
  # under Dolphin's and Konsole's control.
  programs.plasma = {
    configFile = {
      dolphinrc = {
        General.GlobalViewProps = true;
        IconsMode = {
          IconSize = 48;
          PreviewSize = 64;
          UseSystemFont = false;
          ViewFont = qtFont lilyaTheme.fonts.sans (lilyaTheme.fonts.size - 1);
          TextWidthIndex = 1;
          MaximumTextLines = 2;
        };
      };
      konsolerc."Desktop Entry".DefaultProfile = "Lilya.profile";
    };

    dataFile."konsole/Lilya.profile" = {
      General.Name = "Lilya";
      Appearance.Font = qtFont lilyaTheme.fonts.mono lilyaTheme.fonts.terminalSize;
    };
  };
}
