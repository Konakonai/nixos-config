{ pkgs, lib, ... }:

pkgs.buildNpmPackage rec {
  pname = "mcp-server-brave-search";
  version = "0.6.2";

  src = ./mcp-server-brave-search;

  npmDepsHash = "sha256-ekd9btFirSSZkx8ww85ykjnWWf2lQm5XYjkKvd2n2uk=";

  dontNpmBuild = true;

  postInstall = ''
    mkdir -p $out/bin
    ln -s $out/lib/node_modules/mcp-server-brave-search/node_modules/.bin/mcp-server-brave-search $out/bin/mcp-server-brave-search
  '';

  meta = with lib; {
    description = "Brave Search MCP Server";
    homepage = "https://github.com/modelcontextprotocol/servers";
    license = licenses.mit;
  };
}
