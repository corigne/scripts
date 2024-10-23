#!/bin/bash
PICDIR=$HOME/Pictures/sfw

pidof hyprlock && exit 0

PIC=$(ls ~/Pictures/sfw/ | shuf -n1)
PIC2=$(ls ~/Pictures/sfw/ | shuf -n1)

cp "$PICDIR/$PIC" ~/Pictures/.lock_wallpaper
cp "$PICDIR/$PIC2" ~/Pictures/.lock_wallpaper2
hyprlock
