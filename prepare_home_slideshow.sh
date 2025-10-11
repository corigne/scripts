#!/bin/bash

VERBOSE=false
POS_ARGS=()
print_usage() {
  printf "Usage: prepare_animated_slideshow [-options]
  Options:
  -v Verbose output.\n"
}
while getopts 'v' flag; do
  case "${flag}" in
    v) export VERBOSE=true ;;
    *) print_usage
      exit 1 ;;
  esac
done

slideshow=$HOME'/Pictures/slideshow/'
pics=$HOME'/Pictures/'
dirs=($(find $pics -type d -name wallpaper))

echo '//////// CLEANING UP' $slideshow '////////'
let i=0; let k=0
for file in $slideshow/*
do
  if (( $i == ($(tput cols) - 1) ))
  then
    echo
    i=0
  fi
  [ -e "$file" ] && rm "$file" && ((i += 1)) && ((k += 1)) && printf "-"
done
printf '\n%d files cleaned up...\n' $k
echo

echo '///////// TRANSFERRING //////////'
let i=0; let k=0
for dir in ${dirs[@]}
do
  $VERBOSE && echo '\n////////  '$dir'  //////////'
  $VERBOSE && i=0
  for file in "$dir"/*
  do
    if (( $i == ($(tput cols) - 1) ))
    then
      echo
      i=0
    fi
    [ -e "$file" ] && cp "$file" "$slideshow" && ((i += 1)) && ((k += 1)) && printf "+"
  done
done
printf '\n%d files transferred...\n' $k

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
