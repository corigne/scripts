#!/bin/bash
find /tmp/ -maxdepth 1 -regex '.+_maim\.png' -delete
filename=$(date +%s)_maim
maim /tmp/$filename.png -s
xclip -selection clipboard -target image/png -i /tmp/$filename.png
notify-send -t 1500 "Screen captured."
