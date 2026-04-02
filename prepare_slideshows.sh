#!/bin/bash
# prepare_slideshows.sh
#
# Prepares wallpaper and animated GIF slideshows by syncing files from
# categorised source directories into their respective destination directories.
#
# Three sections (all run by default):
#   --home      ~/Pictures/slideshow/           ← all wallpaper/ subdirs
#   --sfw       ~/Pictures/sfw/ + /usr/share/backgrounds/slideshow/
#               ← wallpaper/ subdirs excluding **/questionable/**
#   --animated  ~/Pictures/animated_slideshow/
#               ← animated/ subdirs excluding **/nsfw/**, GIFs are
#                 recoloured with gowall before being copied
#
# Usage: prepare_slideshows.sh [-v] [-j N] [-t THEME] [--home] [--sfw] [--animated]

# ── Defaults ─────────────────────────────────────────────────────────────────

GOWALL_THEME="cat-frappe"
VERBOSE=false

# Parallel jobs for GIF processing.  Benchmarks on the 9800X3D show j=2
# gives near-perfect 2× speedup over sequential; j=4 adds a small gain on
# top.  Clamping nproc/2 to [2, 4] keeps the default conservative enough
# for mobile CPUs (e.g. the pang12/13 reports nproc=16 but has far lower
# sustained per-core throughput than a desktop chip).
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
  -j N      Parallel jobs for animated GIF processing (default: %d, auto from nproc)
  -t THEME  gowall theme applied to animated GIFs (default: %s)
  -v        Verbose output
  --home      Prepare home slideshow only
  --sfw       Prepare SFW slideshow only
  --animated  Prepare animated slideshow only
  (no flags)  Run all three sections\n' "$PARALLEL_JOBS" "$GOWALL_THEME"
}

# getopts only handles short flags; strip long flags out first.
for arg in "$@"; do
  case "$arg" in
    --home)     RUN_HOME=true ;;
    --sfw)      RUN_SFW=true ;;
    --animated) RUN_ANIMATED=true ;;
    --help)     print_usage; exit 0 ;;
  esac
done
# Re-set positional params to only the short flags so getopts can parse them.
eval set -- "$(printf '%s\n' "$@" | grep -v '^--')"

while getopts 'j:t:v' flag; do
  case "$flag" in
    j) PARALLEL_JOBS="$OPTARG" ;;
    t) GOWALL_THEME="$OPTARG" ;;
    v) VERBOSE=true ;;
    *) print_usage; exit 1 ;;
  esac
done

# Default to all sections when none are explicitly requested.
if ! $RUN_HOME && ! $RUN_SFW && ! $RUN_ANIMATED; then
  RUN_HOME=true; RUN_SFW=true; RUN_ANIMATED=true
fi

# Export variables consumed by stylize_gif, which runs in parallel subshells.
export GOWALL_THEME VERBOSE

# ── Cleanup trap ──────────────────────────────────────────────────────────────

# All temp dirs created inside stylize_gif live under WORK_DIR so a single
# rm -rf on exit covers everything, including interrupted parallel jobs.
WORK_DIR=$(mktemp -d)
export WORK_DIR
_cleanup() { rm -rf "$WORK_DIR"; }
trap _cleanup EXIT SIGINT SIGTERM

# ── Shared helper: duplicate basename check ───────────────────────────────────

# Reports source files whose basenames collide, meaning only the last copy
# wins when syncing into a flat destination directory.
check_duplicates() {
  local dest="$1"; shift
  local -a dirs=("$@")

  local sf of
  sf=$(mktemp); of=$(mktemp)

  find "$dest" -type f -exec basename {} \; | sort > "$sf"
  for dir in "${dirs[@]}"; do
    find "$dir" -maxdepth 1 -type f -exec basename {} \;
  done | sort > "$of"

  # comm -13: lines present only in the second file (source dirs).
  # After a full sync these are basenames that didn't survive into dest,
  # which only happens when two source files share the same name.
  local dupes
  dupes=$(comm -13 "$sf" "$of")

  if [[ -n "$dupes" ]]; then
    echo "⚠ Duplicate filenames detected (only the last copy was kept):"
    while IFS= read -r name; do
      echo "  $name"
      find "$dest" -type f -name "$name" -exec echo "    dest:   {}" \;
      for dir in "${dirs[@]}"; do
        find "$dir" -maxdepth 1 -type f -name "$name" -exec echo "    source: {}" \;
      done
    done <<< "$dupes"
    echo
  fi

  rm -f "$sf" "$of"
}

# ── GIF styliser ──────────────────────────────────────────────────────────────

# Recolours a single GIF using the gowall theme.  The pipeline is:
#   gifsicle --explode  →  per-frame .gif files
#   magick              →  convert each frame to .png (gowall requires PNG)
#   gowall convert      →  apply colour theme across the frames directory
#   magick              →  convert processed .png frames back to .gif
#   gifsicle (reassemble) →  stitch frames together with original delays
#
# Runs inside GNU parallel subshells; needs GOWALL_THEME, VERBOSE, WORK_DIR
# exported by the parent.  Each invocation creates its own subdirectory under
# WORK_DIR so jobs are fully isolated and the parent EXIT trap cleans up all
# of them in one shot.
stylize_gif() {
  local file="$1" dest="$2"

  [[ $(file --mime-type -b "$file") == "image/gif" ]] || return 0

  local label
  label="[$(basename "$file")]"

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
  $VERBOSE && echo "$label gowall $frame_count frames → $GOWALL_THEME"

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

  # Reassemble: pair each frame file with its original delay in centiseconds
  # (gifsicle's internal unit; source delays are in seconds).
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

# ── Section: home slideshow ───────────────────────────────────────────────────

run_home() {
  local slideshow="$HOME/Pictures/slideshow/"
  local -a dirs
  mapfile -t dirs < <(find "$HOME/Pictures" -type d -name wallpaper)

  echo "════════ HOME SLIDESHOW ════════"

  local k
  k=$(find "$slideshow" -mindepth 1 -type f -delete -print | wc -l)
  printf 'Cleaned %d existing files\n' "$k"

  find "${dirs[@]}" -maxdepth 1 -type f -print0 | xargs -0 cp -ft "$slideshow"
  printf 'Transferred %d files\n' "$(find "$slideshow" -maxdepth 1 -type f | wc -l)"

  check_duplicates "$slideshow" "${dirs[@]}"
  echo
}

# ── Section: SFW slideshow ────────────────────────────────────────────────────

run_sfw() {
  local slideshow="$HOME/Pictures/sfw/"
  local shared="/usr/share/backgrounds/slideshow/"
  local -a dirs
  mapfile -t dirs < <(
    find "$HOME/Pictures" -type d -name wallpaper -not -path '**/questionable/**'
  )

  echo "════════ SFW SLIDESHOW ════════"

  local k
  k=$(find "$slideshow" -mindepth 1 -type f -delete -print | wc -l)
  sudo find "$shared" -mindepth 1 -type f -delete
  printf 'Cleaned %d user files\n' "$k"

  find "${dirs[@]}" -maxdepth 1 -type f -print0 | xargs -0 cp -ft "$slideshow"
  # Batch the privileged copies in one find+exec to avoid a sudo fork per file.
  sudo find "$slideshow" -type f -exec cp -t "$shared" {} +

  printf 'Transferred %d files\n' "$(find "$slideshow" -maxdepth 1 -type f | wc -l)"

  check_duplicates "$slideshow" "${dirs[@]}"
  echo
}

# ── Section: animated slideshow ───────────────────────────────────────────────

run_animated() {
  local slideshow="$HOME/Pictures/animated_slideshow/"
  local -a dirs
  mapfile -t dirs < <(
    find "$HOME/Pictures" -type d -name animated -not -path '**/nsfw/**'
  )

  echo "════════ ANIMATED SLIDESHOW ════════"
  printf 'Jobs: %d  |  Theme: %s\n\n' "$PARALLEL_JOBS" "$GOWALL_THEME"

  # Snapshot what's already in the destination so we can do an incremental
  # sync (skip already-processed GIFs) and detect orphans afterwards.
  local -a old_files
  mapfile -t old_files < <(find "$slideshow" -name '*.gif' -exec basename {} \;)
  $VERBOSE && printf 'Existing GIFs in dest: %d\n' "${#old_files[@]}"

  local -a new_files to_process
  for dir in "${dirs[@]}"; do
    $VERBOSE && echo "Scanning $dir …"
    for file in "$dir"/*; do
      [[ -f "$file" ]] || continue
      local name; name=$(basename "$file")
      new_files+=("$name")
      # Only queue files not already present in the destination.
      [[ -e "$slideshow/$name" ]] || to_process+=("$file")
    done
  done

  local k="${#to_process[@]}"
  if (( k > 0 )); then
    printf 'Processing %d new GIF(s) with %d parallel job(s)…\n' "$k" "$PARALLEL_JOBS"
    printf '%s\n' "${to_process[@]}" \
      | parallel --jobs "$PARALLEL_JOBS" --bar stylize_gif {} "$slideshow"
  else
    echo "No new GIFs to process."
  fi

  # Remove files that were previously processed but no longer exist in any
  # source directory.  comm -23 outputs lines present only in OLD (sorted).
  local -a orphaned
  mapfile -t orphaned < <(comm -23 \
    <(printf '%s\n' "${old_files[@]}" | sort) \
    <(printf '%s\n' "${new_files[@]}"  | sort))

  local j="${#orphaned[@]}"
  for f in "${orphaned[@]}"; do
    echo "Removing orphan: $f"
    rm "$slideshow/$f"
  done

  printf '%d processed, %d orphans removed\n' "$k" "$j"
  check_duplicates "$slideshow" "${dirs[@]}"
  echo
}

# ── Main ──────────────────────────────────────────────────────────────────────

$RUN_SFW      && run_sfw
$RUN_HOME     && run_home
$RUN_ANIMATED && run_animated
