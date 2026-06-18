{ config, pkgs, ... }:

{
  # Fish Shell 配置
  programs.fish = {
    enable = true;

    shellAliases = {
      ll = "ls -alh";
      la = "ls -A";
      gs = "git status";
      rebuild = "nh os switch /home/lilya/nixos-config -- --impure";
      testbuild = "nh os test /home/lilya/nixos-config -- --impure";
    };
  };

  # Bash Shell 配置
  programs.bash = {
    enable = true;

    bashrcExtra = ''
      export PATH="$HOME/.local/bin:$PATH"
    '';

    shellAliases = {
      ll = "ls -alh";
      la = "ls -A";
      gs = "git status";
      rebuild = "nh os switch /home/lilya/nixos-config -- --impure";
      testbuild = "nh os test /home/lilya/nixos-config -- --impure";
    };
  };

  # Starship Prompt 配置
  programs.starship = {
    enable = true;
  };
}
