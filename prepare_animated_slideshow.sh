#!/bin/bash

export GOWALL_THEME="cat-frappe"
export VERBOSE=false
POS_ARGS=()
TMP_DIRS=()

handle_exit() {
  echo "Cleaning up..."
  for dir in ${TMP_DIRS[@]}; do
    $VERBOSE echo Removing "$dir"
    rm -rf $dir
  done
  echo "Exiting."
  exit
}
trap handle_exit EXIT SIGINT SIGTERM

print_usage() {
  printf "Usage: prepare_animated_slideshow [-options]
  Options:
  -t GOWALL_THEME, see gowall list for a list of valid themes.
  -v Verbose output.\n"
}
while getopts 't:v' flag; do
  case "${flag}" in
    t) export GOWALL_THEME="${OPTARG}" ;;
    v) export VERBOSE=true ;;
    *) print_usage
      exit 1 ;;
  esac
done

stylize_gif () {
  FILE=$1
  TARGET=$2

  if [[ $(file --mime-type -b "$FILE") != "image/gif" ]]; then
    $VERBOSE && echo "$FILE a gif!"
    return
  fi

  TMP_DIR=$(mktemp -d)
  TMP_DIRS+=$TMP_DIR
  $VERBOSE && echo $TMP_DIR
  mkdir -p $TMP_DIR/frames
  mkdir -p $TMP_DIR/processed

  mapfile -t DELAYS < <(gifsicle --info "$FILE" | grep -o 'delay [0-9.]*s' | cut -d' ' -f2 | sed 's/s$//')

  $VERBOSE && echo "Getting GIF dimensions..."
  # Extract dimensions from gifsicle info
  dimensions=$(gifsicle --info "$FILE" | grep -o '[0-9]\+x[0-9]\+' | head -1)
  if [[ ! $? -eq 0 ]]; then
    echo "Error getting dimensions of: $FILE"
    return
  fi
  width=$(echo "$dimensions" | cut -d'x' -f1)
  height=$(echo "$dimensions" | cut -d'x' -f2)

  $VERBOSE && echo "GIF dimensions: ${width}x${height}"

  # Determine if upscaling is needed (adjust thresholds as needed)
  MIN_WIDTH=2560
  MIN_HEIGHT=1440
  NEEDS_UPSCALE=false

  if [ "$width" -lt "$MIN_WIDTH" ] || [ "$height" -lt "$MIN_HEIGHT" ]; then
    NEEDS_UPSCALE=true
    # Calculate upscale factor to meet minimum dimensions
    width_scale=$(echo "scale=2; $MIN_WIDTH / $width" | bc -l)
    height_scale=$(echo "scale=2; $MIN_HEIGHT / $height" | bc -l)

    # Use the larger scale factor to ensure both dimensions meet minimum
    if (( $(echo "$width_scale > $height_scale" | bc -l) )); then
      scale_factor_float="$width_scale"
    else
      scale_factor_float="$height_scale"
    fi

    # Round to nearest integer using bc
    scale_factor=$(echo "$scale_factor_float + 0.5" | bc -l | cut -d'.' -f1)

    # Ensure minimum scale factor of 2 if upscaling is needed
    if [ "$scale_factor" -lt 2 ]; then
      scale_factor=2
    fi

    new_width=$((width * scale_factor))
    new_height=$((height * scale_factor))

    $VERBOSE && echo "Upscaling needed: ${scale_factor}x (${width}x${height} -> ${new_width}x${new_height})"
  else
    $VERBOSE && echo "No upscaling needed"
  fi

  TMP_FILENAME=$TMP_DIR/$(basename $FILE)
  cp $FILE $TMP_FILENAME
  gifsicle --explode --unoptimize $TMP_FILENAME --output="$TMP_DIR/frames/frame"
  if [[ ! $? -eq 0 ]]; then
    echo "Error exploding gif: $FILE."
    return
  fi

  $VERBOSE && echo "Converting frames from .gif to .png for processing."
  for file in "$TMP_DIR"/frames/*; do
    magick "$file" "$file.png"
    rm "$file"
  done
  frame_count=$(ls "$TMP_DIR"/frames | rg -c ".png")

  $VERBOSE && echo "Processing ${frame_count} frames..."
  $VERBOSE && ls $TMP_DIR
  gowall convert --dir "$TMP_DIR/frames" -t $GOWALL_THEME --output="$TMP_DIR/processed" 1>/dev/null
  if [[ ! $? -eq 0 ]]; then
    echo "Error trying to convert frames with gowall."
    return
  fi

 #  if [ "$NEEDS_UPSCALE" = true ]; then
 #    $VERBOSE && echo "Upscaling by $scale_factor"
 #    for img in "$TMP_DIR"/processed; do
 #      if [[ -f "$img" ]]; then
 #        filename=$(basename "$img")
 #        magick "$img" -filter Lanczos -resize ${scale_factor}00% "$TMP_DIR/processed/$filename"
 #      fi
 #    done

 #    if [ $? -ne 0 ]; then
 #      echo "Error trying to upscale frames with ImageMagick."
 #      return
 #    fi
 #  fi

  $VERBOSE && echo "Converting back to .gif"
  for img in "$TMP_DIR"/processed/*; do
    if [[ -f "$img" ]]; then
      filename=$(basename "$img")
      magick "$img" "$TMP_DIR/processed/$(basename -s .png $filename).gif"
      rm $img
    fi
  done

  $VERBOSE && echo "Reassembling GIF with original delays..."
  # Build gifsicle command with delays
  cmd_args=()
  for i in $(seq 0 $((frame_count - 1))); do
    frame_num=$(printf "%03d" $i)
    processed_frame="$TMP_DIR/processed/frame.$frame_num.gif"

    if [ -f "$processed_frame" ]; then
      # Convert delay back to centiseconds (gifsicle uses 1/100s)
      delay_cs=$(echo "${DELAYS[i]} * 100" | bc -l | cut -d'.' -f1)
      cmd_args+=("--delay=$delay_cs" "$processed_frame")
    fi
  done
  $VERBOSE && echo cmd_args = ${cmd_args[@]}
  gifsicle "${cmd_args[@]}" --output="$TARGET$(basename $FILE)"
  rm -rf $TMP_DIR
}

slideshow=$HOME'/Pictures/animated_slideshow/'
pics=$HOME'/Pictures/'
dirs=($(find $pics -type d -name animated -not -path "**/nsfw/**"))

echo '///////// PREPARING //////////'
mapfile -d"\n" OLD_FILES < <(find $slideshow -name "*.gif")
for file in ${OLD_FILES[@]}
do
  file=$(basename $file)
done
$VERBOSE && echo "Existing gifs:"
$VERBOSE && printf "%s\n" ${OLD_FILES[@]}
NEW_FILES=()
let i=0; let k=0
for dir in ${dirs[@]}
do
  $VERBOSE && printf '\n//////// %s //////////\n' $dir
  $VERBOSE && i=0
  for file in "$dir"/*
  do
    [ -f "$file" ] || continue
    NEW_FILES+=$(basename $file)
    [ -e "$slideshow$(basename $file)" ] && continue
    if (( $i == ($(tput cols) - 1) ))
    then
      echo
      i=0
    fi
    [ -e "$file" ] && stylize_gif $file $slideshow && ((i += 1)) && ((k += 1)) && printf "+"
    $VERBOSE && echo $file
  done
  # delete previously processed files which aren't in the incoming/existing files
done

DIFF=($(echo ${OLD_FILES[@]} ${NEW_FILES[@]} | tr ' ' '\n' | sort | uniq -u))
$VERBOSE && echo "New set: ${NEW_FILES[@]}"
$VERBOSE && echo "Diff set: ${DIFF[@]}"
let j=0 # number of deletions
for file in $(echo ${OLD_FILES[@]} ${DIFF[@]} | tr ' ' '\n' | sort | uniq -D | uniq)
do
  if (( $i == ($(tput cols) - 1) ))
  then
    echo
    i=0
  fi
  ((i += 1)) && ((j += 1)) && printf "-"
  echo Removing $slideshow$(basename $file)
  rm $slideshow$(basename $file)
done

printf '\n%d files transferred, removed %d no longer in filesystem...\n' $k $j

# Create temporary files to store filenames with their full paths
slideshow_files=$(mktemp)
other_files=$(mktemp)

# Get slideshow files (basename -> full path mapping)
find "$slideshow" -type f -exec basename {} \; | sort > "$slideshow_files"

# Get other directory files (basename -> full path mapping)
for dir in $dirs; do
  find "$dir" -type f -exec basename {} \;
done | sort > "$other_files"

# Find duplicate basenames
DUPE_BASENAMES="$(diff "$slideshow_files" "$other_files" | grep "^>" | sed 's/^> //')"

if [ "$DUPE_BASENAMES" != "" ]; then
  echo "Possible duplicates in filesystem:"

    # For each duplicate basename, show full paths
    echo "$DUPE_BASENAMES" | while read -r basename; do
    echo "File: $basename"

        # Find in slideshow directory
        find "$slideshow" -type f -name "$basename" -exec echo "  Slideshow: {}" \;

        # Find in other directories
        for dir in $dirs; do
          find "$dir" -type f -name "$basename" -exec echo "  Other: {}" \;
        done
        echo
      done
fi

# Cleanup
rm -f "$slideshow_files" "$other_files"
echo
