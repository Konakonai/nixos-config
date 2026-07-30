# lilya's NixOS configuration

## Agent Notice

If you are an automated coding agent working in this repository, read
`AGENTS.md` before making changes. It defines the required workflow,
verification, commit, and push rules for this machine configuration.

Personal NixOS + Home Manager configuration for a light niri desktop.

## Layout

- `configuration.nix`: thin NixOS entry point for the host hardware module and system state version.
- `home.nix`: thin Home Manager entry point for the user identity and home state version.
- `modules/system/default.nix`: explicit system-module aggregator.
- `modules/home/default.nix`: explicit Home Manager module aggregator.
- `modules/system/`: NixOS system modules.
- `modules/home/`: Home Manager modules for applications, desktop tools, shells, and user services.
- `modules/home/apps/`: browser, desktop-application, and messaging package groups.
- `modules/system/services/`: system daemons, including the OpenList server.
- `modules/home/services/`: user-session services and mounts, including OpenList WebDAV.
- `modules/home/desktop/`: desktop entries, MIME defaults, Zed, media playback defaults, and font aliases.
- `modules/system/display/`: Niri/Plasma login sessions, SDDM, console, portals, and desktop service glue.
- `modules/system/power/`: base power services, battery conservation, device udev rules, and the battery-saver specialisation.
- `modules/system/virtualization.nix`: libvirt/virt-manager and the external Windows whole-disk VM launcher.
- `modules/home/theme/`: GTK, Qt, cursor, Xresources, dconf, Flatpak theme integration, and custom Fcitx/Rime icon wiring.
- `modules/home/niri/`: niri core settings, visual effects, and focused keybinding groups.
- `modules/shared/`: values shared by NixOS and Home Manager, currently the glass design tokens.
- `modules/`: contains only the `system`, `home`, and `shared` layers.
- `hosts/lilya-thinkbook/`: machine-specific display, GPU, power, user path, and service state locations.
- `pkgs/default.nix`: the single local package-set entry point consumed through `pkgs.lilya`.
- `pkgs/`: small local package definitions and wrappers; binary sources are fetched with pinned hashes.

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

## External Windows VM

The application menu entry **External Windows 11** starts the Windows
installation on the aigo U397 through KVM/libvirt. The launcher identifies the
disk by its USB serial, unmounts only that disk's mounted partitions, refuses
to start if any remain mounted, and then opens a SPICE console.

After first enabling this module, log out and back in (or reboot) so the user
session receives membership in the `libvirtd` group. Shut Windows down inside
the guest before unplugging the disk or booting it natively. Do not mount its
NTFS partitions in Linux while the VM is running. Netflix 4K and HDCP still
need native Windows boot and the physical NVIDIA/display path.

On the first virtual boot, open the `SPICE_TOOLS` CD in Windows and run
`Install-Guest-Tools.cmd` as Administrator. Restart Windows afterward. The
QXL driver and SPICE agent provide dynamic resolution, clipboard integration,
and substantially smoother window resizing.

The windowed VM intentionally does not expose nested VMX. Hyper-V and WSL2
remain available when Windows is booted natively, but cannot run inside this
VM; exposing nested VMX makes this removable Windows installation hang while
starting Windows Boot Manager.
