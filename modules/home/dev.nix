{ pkgs, lib, inputs, hostProfile, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  unstable = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
  braveSearchMcp = import ../../pkgs/mcp-server-brave-search.nix {
    inherit pkgs lib;
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
    inputs.hermes-agent.packages.${system}.default
    unstable.officecli
  ];

  home.file.".gemini/config/mcp_config.json".text =
    builtins.toJSON antigravityMcpConfig;

  home.activation.migrateBraveSearchMcpKey =
    lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      oldConfig="$HOME/.gemini/config/mcp_config.json"
      envFile=${lib.escapeShellArg hostProfile.mcp.braveSearch.envFile}

      if [ -f "$oldConfig" ]; then
        key="$(${lib.getExe pkgs.jq} -r '.mcpServers."brave-search".env.BRAVE_API_KEY // empty' "$oldConfig" 2>/dev/null || true)"

        if [ -n "$key" ]; then
          if [ ! -e "$envFile" ]; then
            mkdir -p "$(dirname "$envFile")"
            umask 077
            {
              printf 'BRAVE_API_KEY='
              printf '%s\n' "$key" | ${lib.getExe pkgs.jq} -Rr @sh
            } > "$envFile"
            chmod 600 "$envFile"
          fi

          scrubbedConfig="$(mktemp "$oldConfig.XXXXXX")"
          if ${lib.getExe pkgs.jq} '
            del(.mcpServers."brave-search".env.BRAVE_API_KEY)
            | if .mcpServers."brave-search".env == {} then
                del(.mcpServers."brave-search".env)
              else
                .
              end
          ' "$oldConfig" > "$scrubbedConfig"; then
            mv "$scrubbedConfig" "$oldConfig"
            chmod 644 "$oldConfig"
          else
            rm -f "$scrubbedConfig"
          fi
        fi
      fi
    '';
}
