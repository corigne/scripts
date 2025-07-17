#!/bin/bash
PICDIR=$HOME/Pictures/sfw

THEME="$1"
if [[ "$1" == "" || $(gowall list | grep -c $THEME) -ne 1 ]]; then
    THEME=""
else
    THEME="-t $THEME"
fi

pidof hyprlock && exit 0

PIC=$(ls ~/Pictures/sfw/ | shuf -n1)
PIC2=$(ls ~/Pictures/sfw/ | shuf -n1)

# cp "$PICDIR/$PIC" ~/Pictures/.lock_wallpaper
# cp "$PICDIR/$PIC2" ~/Pictures/.lock_wallpaper
gowall convert "$PICDIR/$PIC" $THEME --output ~/Pictures/.lock_wallpaper --format png
gowall convert "$PICDIR/$PIC2" $THEME --output ~/Pictures/.lock_wallpaper2 --format png

hyprlock
