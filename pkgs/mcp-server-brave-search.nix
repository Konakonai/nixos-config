{ pkgs, lib, braveApiEnvFile ? null, ... }:

let
  envFileRun = lib.optionalString (braveApiEnvFile != null) "--run ${
    lib.escapeShellArg "if [ -z \"\${BRAVE_API_KEY:-}\" ] && [ -f ${lib.escapeShellArg braveApiEnvFile} ]; then set -a; . ${lib.escapeShellArg braveApiEnvFile}; set +a; fi"
  }";
in
pkgs.buildNpmPackage rec {
  pname = "mcp-server-brave-search";
  version = "0.6.2";

  src = ./mcp-server-brave-search;

  npmDepsHash = "sha256-ekd9btFirSSZkx8ww85ykjnWWf2lQm5XYjkKvd2n2uk=";

  nativeBuildInputs = [
    pkgs.makeWrapper
  ];

  dontNpmBuild = true;

  postInstall = ''
    mkdir -p $out/bin
    makeWrapper \
      $out/lib/node_modules/${pname}/node_modules/@modelcontextprotocol/server-brave-search/dist/index.js \
      $out/bin/mcp-server-brave-search \
      ${envFileRun}
  '';

  meta = with lib; {
    description = "Brave Search MCP Server";
    homepage = "https://github.com/modelcontextprotocol/servers";
    license = licenses.mit;
    mainProgram = "mcp-server-brave-search";
  };
}
