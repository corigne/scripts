# Scripts

Personal shell utilities. Maintained desktop commands live in `bin/`; older and
unrelated scripts remain at the repository root.

## Installation

`bin/` is laid out for GNU Stow:

```sh
cd /path/to/Scripts
mkdir -p "$HOME/.local/bin"
stow --dir="$PWD" --target="$HOME/.local/bin" bin
```

This links only commands from `bin/`; unrelated root scripts remain untouched.
Ensure `~/.local/bin` is in `PATH`.
To install selected commands without Stow:

```sh
install -Dm755 bin/screenshot-full "$HOME/.local/bin/screenshot-full"
```

## Commands

Compositor-neutral commands:

| Command | Purpose | Dependencies |
| --- | --- | --- |
| `screenshot-full` | Capture all outputs and copy the image | `grim`, `wl-clipboard`, `libnotify` |
| `screenshot-region` | Freeze, select, capture, and copy a region | `wayfreeze`, `slurp`, `grim`, `wl-clipboard`, `libnotify` |
| `thunar-extract-here` | Extract archives beside their source | `7z`, `ghostty`, `libnotify` |
| `thunar-extract-to-folder` | Extract each archive to a named folder | `7z`, `ghostty`, `libnotify` |
| `awww-slideshow` | Legacy multi-output `awww` slideshow | `awww`, `gowall`, GNU `parallel`, `file`, `find`, `shuf` |
| `awww-slideshow-control` | Signal the running slideshow by its runtime PID | POSIX `sh`, `grep`, `tr` |
| `gimp-open-folder` | Open one folder's images in GIMP | `gimp`, `find`, `xargs` |
| `krita` | Launch Krita with the retained Wayland scaling environment | `krita` |
| `prepare-slideshows` | Build static and animated wallpaper collections | `rsync`; animated mode also needs `parallel`, `gowall`, `gifsicle`, ImageMagick, `bc`, `file` |
| `wake-on-lan` | Discover hosts and send a Wake-on-LAN packet | `arp`, `getent`, plus `wol`, `wakeonlan`, or `etherwake` |
| `wtfioh` | Show largest filesystem entries below a path | `sudo`, `du`, `sort`, `head` |

`awww-slideshow` discovers outputs through `awww query`; it does not query a
compositor. Niri wallpaper is expected to be managed by Noctalia instead.

Control the running instance without process-name matching:

```sh
awww-slideshow-control pause
awww-slideshow-control resume
awww-slideshow-control restart
awww-slideshow-control stop
awww-slideshow-control signal USR1
```

`signal` accepts `HUP`, `TERM`, `USR1`, or `USR2`. The helper reads
`$XDG_RUNTIME_DIR/awww-slideshow.pid`, verifies the PID belongs to
`awww-slideshow`, then signals only that process.

Retained Hyprland-only commands:

| Command | Purpose | Dependencies |
| --- | --- | --- |
| `hypr-lock` | Run Hyprlock, then prepare lock wallpapers | `hyprlock`, `gowall`, `find`, `shuf` |
| `hypr-lock-before-sleep` | Start the suspend-specific lock | `hyprlock` |
| `hypr-prepare-for-sleep` | Disable outputs and replace stale lock clients | `hyprctl`, `hyprlock` |
| `hypr-lock-after-sleep` | Verify the fresh lock and restore outputs | `hyprctl`, `hyprlock` |
| `hypr-idle` | Legacy Hyprland idle policy | `swayidle`, `swaylock`, `hyprctl`, `playerctl` |
| `hypr-gamemode` | Toggle Hyprland effects and slideshow pause | `hyprctl` |
| `hypr-kill` | Select and terminate one Hyprland window | `hyprprop`, `jq` |
| `hypr-wayvnc` | Run WayVNC on a Hyprland headless output | `hyprctl`, `wayvnc` |

Runtime PID files, state lists, and temporary screenshots/extraction lists use
`XDG_RUNTIME_DIR`.

## thunar-extract-here / thunar-extract-to-folder

Thunar custom actions for archive extraction, similar to 7-Zip's context menu on Windows.

**Dependencies:** `7z`, `ghostty`, `notify-send`

**Features:**
- Opens a floating Ghostty terminal showing live extraction progress
- Auto-closes on success; stays open (with prompt) on failure
- Sends a `notify-send` notification on completion
- Supports: `.zip .7z .rar .tar .tar.gz .tar.bz2 .tar.xz .tar.zst .tgz .tbz2 .txz .gz .bz2 .xz .zst`

### Installation

```bash
install -Dm755 bin/thunar-extract-here "$HOME/.local/bin/thunar-extract-here"
install -Dm755 bin/thunar-extract-to-folder "$HOME/.local/bin/thunar-extract-to-folder"
```

Add to `~/.config/Thunar/uca.xml` inside `<actions>`:

```xml
<action>
    <icon>utilities-file-archiver</icon>
    <name>Extract Here</name>
    <submenu></submenu>
    <unique-id>thunar-extract-here-1</unique-id>
    <command>/home/YOUR_USER/.local/bin/thunar-extract-here %F</command>
    <description>Extracts the selected archive(s) to the current directory.</description>
    <range>*</range>
    <patterns>*.zip;*.tar.gz;*.tgz;*.tar.bz2;*.tbz2;*.tar.xz;*.txz;*.tar.zst;*.tar;*.7z;*.rar;*.gz;*.bz2;*.xz;*.zst</patterns>
    <other-files/>
</action>
<action>
    <icon>utilities-file-archiver</icon>
    <name>Extract To ./*</name>
    <submenu></submenu>
    <unique-id>thunar-extract-to-folder-1</unique-id>
    <command>/home/YOUR_USER/.local/bin/thunar-extract-to-folder %F</command>
    <description>Extracts each archive to a self-titled subdirectory.</description>
    <range>*</range>
    <patterns>*.zip;*.tar.gz;*.tgz;*.tar.bz2;*.tbz2;*.tar.xz;*.txz;*.tar.zst;*.tar;*.7z;*.rar;*.gz;*.bz2;*.xz;*.zst</patterns>
    <other-files/>
</action>
```

Optionally add Hyprland window rules for a centered floating window:

```
windowrule = float 1, match:class ^io\.nexus\.thunarextract$
windowrule = size 700 400, match:class ^io\.nexus\.thunarextract$
windowrule = center 1, match:class ^io\.nexus\.thunarextract$
```
