# SCRIPTS
A collection of useful shell scripts I've jammed out and thought may be worth sharing.

## thunar-extract-here / thunar-extract-to-folder

Thunar custom actions for archive extraction, similar to 7-Zip's context menu on Windows.

**Dependencies:** `7z`, `ghostty`, `hyprctl`, `jq`, `notify-send`

**Features:**
- Opens a floating Ghostty terminal showing live extraction progress
- Auto-closes on success; stays open (with prompt) on failure
- Sends a `notify-send` notification on completion only when the window isn't focused
- Supports: `.zip .7z .rar .tar .tar.gz .tar.bz2 .tar.xz .tar.zst .tgz .tbz2 .txz .gz .bz2 .xz .zst`

### Installation

```bash
cp thunar-extract-here thunar-extract-to-folder ~/.local/bin/
chmod +x ~/.local/bin/thunar-extract-here ~/.local/bin/thunar-extract-to-folder
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
