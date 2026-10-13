# Scripts

Personal shell utilities. Public commands live in `bin/`; desktop-specific
implementations live behind them in `libexec/wayland-backends/`.

## Installation

`bin/` is laid out for GNU Stow:

```sh
cd /path/to/Scripts
mkdir -p "$HOME/.local/bin"
stow --dir="$PWD" --target="$HOME/.local/bin" bin
```

The dotfiles profile links `bin/` into `~/.local/bin` and `libexec/` into
`~/.local/libexec/dotfiles`. Ensure `~/.local/bin` is in `PATH`.
To install selected commands without Stow:

```sh
install -Dm755 bin/screenshot-full "$HOME/.local/bin/screenshot-full"
```

## Commands

Compositor-neutral commands:

| Command | Purpose | Dependencies |
| --- | --- | --- |
| `wayland-backend` | Identify the active supported Wayland desktop | POSIX `sh` |
| `screenshot-full` | Capture all outputs and copy the image | Niri: `grim`; Plasma: `spectacle`; both: `wl-clipboard`, `libnotify` |
| `screenshot-region` | Interactively capture and copy a region | Niri: `wayfreeze`, `slurp`, `grim`; Plasma: `spectacle`; both: `wl-clipboard`, `libnotify` |
| `thunar-extract-here` | Extract archives beside their source | `7z`, `ghostty`, `libnotify` |
| `thunar-extract-to-folder` | Extract each archive to a named folder | `7z`, `ghostty`, `libnotify` |
| `wallpaper-collection-select` | Persist and select from the active wallpaper collection | POSIX `sh`, `find`, `jq`, `shuf` |
| `wallpaper-random` | Select a collection through the active desktop backend | POSIX `sh`; Niri/Noctalia or Plasma |
| `wallpaper-next` | Advance the active collection through the active desktop backend | POSIX `sh`; Niri/Noctalia or Plasma |
| `gimp-open-folder` | Open one folder's images in GIMP | `gimp`, `find`, `xargs` |
| `krita` | Launch Krita with the retained Wayland scaling environment | `krita` |
| `prepare-slideshows` | Build static and animated wallpaper collections | `rsync`; animated mode also needs `parallel`, `gowall`, `gifsicle`, ImageMagick, `bc`, `file` |
| `wake-on-lan` | Discover hosts and send a Wake-on-LAN packet | `arp`, `getent`, plus `wol`, `wakeonlan`, or `etherwake` |
| `wtfioh` | Show largest filesystem entries below a path | `sudo`, `du`, `sort`, `head` |

Collection state is stored under
`$XDG_STATE_HOME/wallpaper-collection/state.json`. Public wallpaper commands
contain no compositor IPC. `wayland-backend` dispatches them to:

- Niri/Noctalia: distinct per-output assignments and animated collections;
- Plasma: stock `plasma-apply-wallpaperimage` with one static assignment.

The Noctalia profile disables its native fixed-directory automation. The Niri
profile's `wallpaper-collection.timer` calls the portable `wallpaper-next`
dispatcher every five minutes, so automatic changes use the same active
collection state. Plasma is a manual recovery desktop and does not start that
timer. Scripts do not rewrite desktop configuration.

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

The extraction terminal uses application ID `io.nexus.thunarextract` so any
Wayland desktop can apply an optional floating-window rule locally.
