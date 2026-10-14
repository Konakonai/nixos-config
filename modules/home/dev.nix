{ pkgs, ... }:

let
  python = pkgs.python3.withPackages (
    pythonPackages: with pythonPackages; [
      beautifulsoup4
      ipython
      jupyterlab
      lxml
      matplotlib
      numpy
      openpyxl
      pandas
      pillow
      python-docx
      requests
      rich
      scikit-learn
      scipy
      seaborn
    ]
  );
in
{
  programs.gh.enable = true;

  home.packages = with pkgs; [
    gcc
    rustup
    go
    nodejs
    python
    lua
    git-lfs
    android-tools
  ];
}
