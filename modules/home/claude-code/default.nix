{
  # Claude Code auto-loads a plugin from any folder under ~/.claude/skills that
  # holds a .claude-plugin/plugin.json, in the CLI and in the desktop app's Code
  # tab alike. The folder is linked whole, not file by file (`recursive`): the
  # engine resolves each hook module's real path and refuses one that lands
  # outside the plugin folder, which per-file store links always do.
  home.file.".claude/skills/token-band".source = ./token-band;
}
