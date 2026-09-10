{ pkgs, lib, hostProfile, ... }:

let
  braveSearchMcp = pkgs.lilya.mcp-server-brave-search {
    braveApiEnvFile = hostProfile.mcp.braveSearch.envFile;
  };
  antigravityMcpConfig = {
    mcpServers."brave-search" = {
      command = lib.getExe braveSearchMcp;
    };
  };
  python = pkgs.python3.withPackages (pythonPackages: with pythonPackages; [
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
  ]);
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

    braveSearchMcp
  ];

  home.file.".gemini/config/mcp_config.json".text =
    builtins.toJSON antigravityMcpConfig;
}
