#!/bin/bash
# prepare_slideshows.sh
#
# Incrementally syncs wallpaper and animated GIF slideshows from categorised
# source directories.  Only copies new files and removes orphans — never
# redundantly re-copies unchanged files.
#
# The animated section recolours each GIF with gowall before placing it in
# its destination; all other sections perform a plain file copy.
#
# Three sections (all run by default):
#   --home      ~/Pictures/slideshow/
#               ← all wallpaper/ subdirs under ~/Pictures
#   --sfw       ~/Pictures/sfw/ + /usr/share/backgrounds/slideshow/
#               ← wallpaper/ subdirs excluding **/questionable/**
#               (requires passwordless sudo for the shared system directory)
#   --animated  ~/Pictures/animated_slideshow/
#               ← animated/ subdirs excluding **/nsfw/**
#
# Usage: prepare_slideshows.sh [-v] [-j N] [-t THEME] [--home] [--sfw] [--animated]

# ── Defaults ─────────────────────────────────────────────────────────────────

GOWALL_THEME="cat-frappe"
VERBOSE=false

# Default parallel jobs: nproc/2 clamped to [2, 4].
# Benchmarks on the 9800X3D show j=2 gives near-perfect 2× speedup over
# sequential; j=4 adds a small further gain.  The upper clamp keeps the
# default conservative enough for mobile CPUs — the pang12/13 reports
# nproc=16 but has much lower sustained per-core throughput than a desktop.
# Override with -j N.
_half=$(( $(nproc) / 2 ))
PARALLEL_JOBS=$(( _half < 2 ? 2 : _half > 4 ? 4 : _half ))
unset _half

RUN_HOME=false
RUN_SFW=false
RUN_ANIMATED=false

# ── Argument parsing ──────────────────────────────────────────────────────────

print_usage() {
  printf 'Usage: prepare_slideshows [options] [--home] [--sfw] [--animated]

Options:
  -j N      Parallel jobs for animated GIF processing (default: %d)
  -t THEME  gowall theme for animated GIFs (default: %s)
  -v        Verbose output
  --home      Sync home wallpaper slideshow only
  --sfw       Sync SFW slideshow only
  --animated  Sync animated GIF slideshow only
  (no flags)  Run all three sections\n' "$PARALLEL_JOBS" "$GOWALL_THEME"
}

# Handle long options first (getopts only understands short flags).
for arg in "$@"; do
  case "$arg" in
    --home)     RUN_HOME=true ;;
    --sfw)      RUN_SFW=true ;;
    --animated) RUN_ANIMATED=true ;;
    --help)     print_usage; exit 0 ;;
  esac
done

# Rebuild positional params without long flags so getopts can process the rest.
_remaining=()
for arg in "$@"; do [[ "$arg" == --* ]] || _remaining+=("$arg"); done
set -- "${_remaining[@]}"
unset _remaining

while getopts 'j:t:v' flag; do
  case "$flag" in
    j) PARALLEL_JOBS="$OPTARG" ;;
    t) GOWALL_THEME="$OPTARG" ;;
    v) VERBOSE=true ;;
    *) print_usage; exit 1 ;;
  esac
done

if ! $RUN_HOME && ! $RUN_SFW && ! $RUN_ANIMATED; then
  RUN_HOME=true; RUN_SFW=true; RUN_ANIMATED=true
fi

# Export variables consumed by stylize_gif, which runs in parallel subshells.
export GOWALL_THEME VERBOSE

# ── Dependency check ──────────────────────────────────────────────────────────

_check_deps() {
  local -a missing=()

  # rsync is used to mirror the SFW slideshow to the shared system directory.
  $RUN_SFW && command -v rsync &>/dev/null || { $RUN_SFW && missing+=(rsync); }

  # These tools are only needed for the animated section.
  if $RUN_ANIMATED; then
    for cmd in parallel gowall gifsicle magick bc file; do
      command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
  fi

  if (( ${#missing[@]} > 0 )); then
    printf 'Error: missing required tools: %s\n' "${missing[*]}" >&2
    exit 1
  fi
}
_check_deps

# ── Cleanup trap ──────────────────────────────────────────────────────────────

# All temp dirs created by stylize_gif live under WORK_DIR, so a single
# rm -rf on exit covers everything including any interrupted parallel jobs.
WORK_DIR=$(mktemp -d)
export WORK_DIR
_cleanup() { rm -rf "$WORK_DIR"; }
trap _cleanup EXIT SIGINT SIGTERM

# ── Helpers ───────────────────────────────────────────────────────────────────

# Emit sorted array contents.  Produces no output for empty arrays, which
# prevents spurious empty-line ghost matches when used in comm process
# substitutions.
_sorted() { (( $# )) && printf '%s\n' "$@" | sort; }

# Report source files whose basenames collide across source directories.
# In a flat destination only the last copy of a duplicate name survives.
check_duplicates() {
  local dest="$1"; shift
  local -a dirs=("$@")

  local sf of
  sf=$(mktemp); of=$(mktemp)
  find "$dest" -maxdepth 1 -type f -exec basename {} \; | sort > "$sf"
  for dir in "${dirs[@]}"; do
    find "$dir" -maxdepth 1 -type f -exec basename {} \;
  done | sort > "$of"

  # comm -13: lines only in the second file (source dirs).  After a full sync
  # these are basenames that didn't survive into dest due to a name collision.
  local dupes
  dupes=$(comm -13 "$sf" "$of")
  if [[ -n "$dupes" ]]; then
    echo "⚠ Duplicate filenames (last copy wins):"
    while IFS= read -r name; do
      echo "  $name"
      find "$dest" -maxdepth 1 -type f -name "$name" -exec echo "    dest:   {}" \;
      for dir in "${dirs[@]}"; do
        find "$dir" -maxdepth 1 -type f -name "$name" -exec echo "    source: {}" \;
      done
    done <<< "$dupes"
    echo
  fi
  rm -f "$sf" "$of"
}

# ── Copy steps ────────────────────────────────────────────────────────────────

# Plain copy: used for static wallpaper slideshows.
# Receives (dest, file…) for files confirmed absent from dest.
_copy_plain() {
  local dest="$1"; shift
  printf '%d file(s) to copy…\n' "$#"
  printf '%s\0' "$@" | xargs -0 cp -ft "$dest"
}

# GIF processing copy step: recolour each GIF with gowall, then place in dest.
# stylize_gif is exported so GNU parallel can invoke it in subshells.
_copy_gif() {
  local dest="$1"; shift
  printf 'Processing %d new GIF(s) with %d parallel job(s)…\n' "$#" "$PARALLEL_JOBS"
  printf '%s\n' "$@" | parallel --jobs "$PARALLEL_JOBS" --bar stylize_gif {} "$dest"
}

# ── Core sync engine ──────────────────────────────────────────────────────────

# Incrementally syncs a flat destination directory from one or more source dirs:
#   new files  (in any source, absent from dest)  → passed to copy_fn
#   orphans    (in dest, absent from all sources)  → deleted
#   duplicates (same basename across source dirs)  → reported
#
# Usage: sync_slideshow dest copy_fn source_dir [source_dir …]
sync_slideshow() {
  local dest="$1" copy_fn="$2"; shift 2
  local -a dirs=("$@")

  # Snapshot current dest basenames so we can detect orphans after the scan.
  local -a old_files
  mapfile -t old_files < <(find "$dest" -maxdepth 1 -type f -exec basename {} \;)

  # Walk each source dir one level deep to build the canonical source name set
  # and identify files not yet present in dest.
  local name
  local -a new_files to_copy
  for dir in "${dirs[@]}"; do
    $VERBOSE && echo "Scanning $dir …"
    for file in "$dir"/*; do
      [[ -f "$file" ]] || continue
      name=$(basename "$file")
      new_files+=("$name")
      [[ -e "$dest/$name" ]] || to_copy+=("$file")
    done
  done

  if (( ${#to_copy[@]} > 0 )); then
    "$copy_fn" "$dest" "${to_copy[@]}"
  else
    echo "Nothing new."
  fi

  # comm -23 <(old|sorted) <(new|sorted): lines only in old = orphans.
  local -a orphaned
  mapfile -t orphaned < <(comm -23 <(_sorted "${old_files[@]}") <(_sorted "${new_files[@]}"))

  for f in "${orphaned[@]}"; do
    echo "Removing orphan: $f"
    rm "$dest/$f"
  done

  printf '%d synced, %d orphans removed\n' "${#to_copy[@]}" "${#orphaned[@]}"
  check_duplicates "$dest" "${dirs[@]}"
}

# ── GIF styliser (exported for GNU parallel) ──────────────────────────────────

# Recolours a single GIF with the configured gowall theme.  Pipeline:
#   gifsicle --explode  →  per-frame .gif files
#   magick              →  each frame .gif → .png  (gowall requires PNG input)
#   gowall convert      →  apply colour theme to the whole frames directory
#   magick              →  each processed .png → .gif
#   gifsicle            →  reassemble frames with their original per-frame delays
#
# Runs in GNU parallel subshells; GOWALL_THEME, VERBOSE, WORK_DIR must be
# exported.  Each call gets its own isolated subdirectory under WORK_DIR.
stylize_gif() {
  local file="$1" dest="$2"
  local label="[$(basename "$file")]"

  [[ $(file --mime-type -b "$file") == "image/gif" ]] || return 0

  local tmp
  tmp=$(mktemp -d -p "$WORK_DIR")
  mkdir -p "$tmp/frames" "$tmp/processed"

  # Capture per-frame delays before exploding (gifsicle reports in seconds).
  local -a delays
  mapfile -t delays < <(
    gifsicle --info "$file" \
      | grep -o 'delay [0-9.]*s' \
      | cut -d' ' -f2 \
      | sed 's/s$//'
  )

  cp "$file" "$tmp/$(basename "$file")"
  gifsicle --explode --unoptimize "$tmp/$(basename "$file")" \
    --output="$tmp/frames/frame" || {
    echo "Error: gifsicle could not explode $file" >&2
    rm -rf "$tmp"; return 1
  }

  $VERBOSE && echo "$label converting frames to PNG…"
  for f in "$tmp"/frames/frame.*; do
    magick "$f" "$f.png" && rm "$f"
  done

  local frame_count
  frame_count=$(find "$tmp/frames" -name '*.png' | wc -l)
  $VERBOSE && echo "$label gowall: $frame_count frames → $GOWALL_THEME"

  gowall convert --dir "$tmp/frames" -t "$GOWALL_THEME" \
    --output="$tmp/processed" 1>/dev/null || {
    echo "Error: gowall failed on $file" >&2
    rm -rf "$tmp"; return 1
  }

  $VERBOSE && echo "$label converting processed frames back to GIF…"
  for img in "$tmp"/processed/*.png; do
    [[ -f "$img" ]] || continue
    magick "$img" "$tmp/processed/$(basename "$img" .png).gif" && rm "$img"
  done

  # Reassemble: pair each frame with its original delay in centiseconds
  # (gifsicle's internal unit; gifsicle --info reports delays in seconds).
  $VERBOSE && echo "$label reassembling…"
  local -a cmd_args=()
  local i frame delay_cs
  for i in $(seq 0 $(( frame_count - 1 ))); do
    frame="$tmp/processed/$(printf 'frame.%03d' "$i").gif"
    [[ -f "$frame" ]] || continue
    delay_cs=$(echo "${delays[$i]} * 100" | bc -l | cut -d'.' -f1)
    cmd_args+=("--delay=$delay_cs" "$frame")
  done

  gifsicle "${cmd_args[@]}" --output="$dest/$(basename "$file")" || {
    echo "Error: gifsicle reassembly failed for $file" >&2
  }

  rm -rf "$tmp"
  echo "$label done"
}
export -f stylize_gif

# ── Section runners ───────────────────────────────────────────────────────────

run_home() {
  local -a dirs
  mapfile -t dirs < <(find "$HOME/Pictures" -type d -name wallpaper)
  echo "════════ HOME SLIDESHOW ════════"
  sync_slideshow "$HOME/Pictures/slideshow/" _copy_plain "${dirs[@]}"
  echo
}

run_sfw() {
  local slideshow="$HOME/Pictures/sfw/"
  local shared="/usr/share/backgrounds/slideshow/"
  local -a dirs
  mapfile -t dirs < <(
    find "$HOME/Pictures" -type d -name wallpaper -not -path '**/questionable/**'
  )

  echo "════════ SFW SLIDESHOW ════════"
  sync_slideshow "$slideshow" _copy_plain "${dirs[@]}"

  # rsync --delete mirrors the user slideshow to the shared system directory,
  # handling both new additions and orphan removal in a single pass.
  # This is where rsync genuinely wins over manual comm logic.
  printf 'Syncing to shared directory…\n'
  sudo rsync --archive --delete "$slideshow" "$shared"
  echo
}

run_animated() {
  local -a dirs
  mapfile -t dirs < <(
    find "$HOME/Pictures" -type d -name animated -not -path '**/nsfw/**'
  )
  echo "════════ ANIMATED SLIDESHOW ════════"
  printf 'Jobs: %d  |  Theme: %s\n\n' "$PARALLEL_JOBS" "$GOWALL_THEME"
  sync_slideshow "$HOME/Pictures/animated_slideshow/" _copy_gif "${dirs[@]}"
  echo
}

# ── Main ──────────────────────────────────────────────────────────────────────

$RUN_SFW      && run_sfw
$RUN_HOME     && run_home
$RUN_ANIMATED && run_animated
