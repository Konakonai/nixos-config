{ pkgs, ... }:

let
  pkg = pkgs.lilya.computer-use-linux;
  packageDir = "${pkg}/share/computer-use-linux";
  skillsDir = "${packageDir}/skills/computer-use-linux";
in
{
  home.packages = [ pkg ];

  # Pi auto-discovers global packages from ~/.pi/agent/extensions/*/package.json
  # (with a `pi.extensions` field) and skills from ~/.pi/agent/skills/*/, so
  # both can stay declarative without touching Pi's mutable settings.json.
  home.file.".pi/agent/extensions/computer-use-linux".source = packageDir;
  home.file.".pi/agent/skills/computer-use-linux".source = skillsDir;

  # Antigravity auto-discovers plugins from ~/.gemini/config/plugins/<name>/
  # and enables them by default, keeping ~/.gemini/config/{config,mcp_config}.json
  # free for runtime UI/CLI edits.
  home.file.".gemini/config/plugins/computer-use-linux/plugin.json".text = builtins.toJSON {
    name = "computer-use-linux";
    displayName = "Computer Use Linux";
    inherit (pkg) version;
    description = "Native Linux desktop control over MCP: AT-SPI accessibility trees, screenshots, window targeting, and Wayland/X11 input.";
    homepage = "https://github.com/agent-sh/computer-use-linux";
    license = "MIT";
  };
  home.file.".gemini/config/plugins/computer-use-linux/mcp_config.json".text = builtins.toJSON {
    mcpServers.computer-use-linux = {
      command = "${pkg}/bin/computer-use-linux";
      args = [ "mcp" ];
    };
  };
  home.file.".gemini/config/plugins/computer-use-linux/skills/computer-use-linux" = {
    source = skillsDir;
    recursive = true;
  };
}
