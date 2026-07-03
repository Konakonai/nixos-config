# lilya's NixOS configuration

## Agent Notice

If you are an automated coding agent working in this repository, read
`AGENTS.md` before making changes. It defines the required workflow,
verification, commit, and push rules for this machine configuration.

Personal NixOS + Home Manager configuration for a light niri desktop.

## Layout

- `configuration.nix`: NixOS system entry point.
- `home.nix`: Home Manager user entry point.
- `modules/system/`: NixOS system modules.
- `modules/home/`: user applications, tools, Noctalia, Zen, Yazi, and user scripts.
- `modules/desktop/`: desktop entries, MIME defaults, Zed, media playback defaults, and font aliases.
- `modules/system/display/`: niri login session, greetd/gtkgreet, console, portals, and desktop service glue.
- `modules/system/power/`: base power services, CPU limits, NVIDIA dGPU switching, AC udev events, and permission helpers.
- `modules/theme/`: GTK, Qt, cursor, Xresources, dconf, Flatpak theme assets, and custom Fcitx/Rime icon integration.
- `modules/niri/`: niri core settings, visual effects, and focused keybinding groups.
- `modules/`: shared Home Manager modules such as shell, kitty, Fcitx5, Codex, Flatpak, and glass settings.
- `hosts/lilya-thinkbook/`: machine-specific display, GPU, power, user path, and service state locations.
- `pkgs/`: small local package definitions; binary sources are fetched with pinned hashes.

Local source archives under `sources/` are intentionally ignored and are not part of the repository.

## Reproducing this machine

`main` is the exact ThinkBook profile. It expects the host facts declared in
`hosts/lilya-thinkbook`, including NVIDIA/Intel render nodes, display
identities, AC/battery sysfs names, and selected USB devices.

The Nix store build is reproducible from the repository and `flake.lock`, but a
fully working user session also needs these external state files restored:

- `/home/lilya/.config/age/mihomo.txt`: agenix identity used to decrypt tracked machine secrets.
- `/home/lilya/.config/antigravity/brave-search.env`: Brave Search API key used by the Antigravity MCP server.
- `/home/lilya/.config/openlist/`: OpenList runtime config and database.
- `/home/lilya/.config/rclone/rclone.conf`: WebDAV mount credentials.

Display layout is applied in the login and niri sessions from stable monitor
identity data rather than DRM connector names, which may change across hybrid
GPU boot paths.
