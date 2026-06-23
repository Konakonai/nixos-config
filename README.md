# lilya's NixOS configuration

Personal NixOS + Home Manager configuration for a light niri desktop.

## Layout

- `configuration.nix`: NixOS system entry point.
- `home.nix`: Home Manager user entry point.
- `modules/system/`: NixOS system modules.
- `modules/home/`: user applications, tools, Noctalia, Zen, Yazi, and user scripts.
- `modules/desktop/`: desktop entries, MIME defaults, Zed, mpv WebDAV, and font aliases.
- `modules/niri/`: niri core settings, visual effects, and focused keybinding groups.
- `modules/`: shared Home Manager modules such as theme, shell, kitty, Fcitx5, Codex, Flatpak, and glass settings.
- `pkgs/`: small local package definitions; binary sources are fetched with pinned hashes.

Local source archives under `sources/` are intentionally ignored and are not part of the repository.
