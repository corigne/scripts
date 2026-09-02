#!/bin/sh
# gimp-open-folder: open all images in a folder (one level deep) in a single GIMP instance

folder="$1"

if [ -z "$folder" ]; then
    echo "Usage: gimp-open-folder <folder>" >&2
    exit 1
fi

if [ ! -d "$folder" ]; then
    echo "Error: '$folder' is not a directory" >&2
    exit 1
fi

find "$folder" -maxdepth 1 -type f \( \
    -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o \
    -iname "*.gif" -o -iname "*.bmp" -o -iname "*.tiff" -o \
    -iname "*.webp" \
    \) -print0 > /tmp/.gimp-open-folder-list.$$

if [ ! -s /tmp/.gimp-open-folder-list.$$ ]; then
    echo "No images found in '$folder'" >&2
    rm -f /tmp/.gimp-open-folder-list.$$
    exit 1
fi

xargs -0 gimp < /tmp/.gimp-open-folder-list.$$
rm -f /tmp/.gimp-open-folder-list.$$
