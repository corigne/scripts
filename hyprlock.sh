#!/bin/bash
PICDIR=$HOME/Pictures/sfw

pidof hyprlock && exit 0

PIC=$(ls ~/Pictures/sfw/ | shuf -n1)

cp "$PICDIR/$PIC" ~/Pictures/.lock_wallpaper
hyprlock
