{ pkgs, ... }:

let
  pkg = pkgs.lilya.opencli;
  skillsDir = "${pkg}/share/opencli/skills";
  skillNames = [
    "opencli-adapter-author"
    "opencli-autofix"
    "opencli-browser"
    "opencli-usage"
  ];
in
{
  home.packages = [ pkg ];

  # Antigravity auto-discovers plugins from ~/.gemini/config/plugins/<name>/
  # and enables them by default, keeping ~/.gemini/config/{config,mcp_config}.json
  # free for runtime UI/CLI edits.
  home.file = {
    ".gemini/config/plugins/opencli/plugin.json".text = builtins.toJSON {
      name = "opencli";
      displayName = "OpenCLI";
      inherit (pkg) version;
      description = "Drive logged-in Chromium/Brave profiles and deterministic site adapters with OpenCLI.";
      homepage = "https://opencli.info";
      repository = "https://github.com/jackwener/OpenCLI";
    };
    ".gemini/config/plugins/opencli/skills" = {
      source = skillsDir;
      recursive = true;
    };
  }
  // builtins.listToAttrs (
    map (name: {
      name = ".pi/agent/skills/${name}";
      value.source = "${skillsDir}/${name}";
    }) skillNames
  );
}
