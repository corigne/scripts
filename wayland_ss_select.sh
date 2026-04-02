#!/bin/bash
find /tmp/ -maxdepth 1 -regex '.+_screenshot\.png' -delete
screenshot_dir="/tmp"
filename=$(date +%s)_screenshot.png
wayfreeze & PID=$!; sleep .1; grim -g "$(slurp)" $screenshot_dir/$filename
kill $PID
wl-copy --type image/png < $screenshot_dir/$filename
notify-send -t 1500 "Screen captured."
