#!/bin/bash
find /tmp/ -maxdepth 1 -regex '.+_screenshot\.png' -delete
filename=$(date +%s)_screenshot
samurai-select -z -s -o /tmp/$filename.png
wl-copy --type image/png < /tmp/$filename.png
notify-send -t 1500 "Screen captured."
