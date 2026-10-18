{
  # Claude Code auto-loads a plugin from any folder under ~/.claude/skills that
  # holds a .claude-plugin/plugin.json, in the CLI and in the desktop app's Code
  # tab alike. `recursive` links each file instead of the folder, so the engine
  # can still lay its editor types into .claude-plugin/types/ beside them.
  home.file.".claude/skills/token-band" = {
    source = ./token-band;
    recursive = true;
  };
}
