#!/bin/bash
PICDIR=$HOME/Pictures/sfw

# Store first argument as theme, shift to get remaining args
THEME="$1"
shift  # Remove first argument, leaving remaining args in $@

# Validate theme
if [[ "$THEME" == "" || $(gowall list | grep -c "$THEME") -ne 1 ]]; then
    THEME=""
else
    THEME="-t $THEME"
fi

# Exit if hyprlock is already running
pidof hyprlock && exit 0

# Select random pictures
PIC=$(ls ~/Pictures/sfw/ | shuf -n1)
PIC2=$(ls ~/Pictures/sfw/ | shuf -n1)
PIC3=$(ls ~/Pictures/sfw/ | shuf -n1)

# Run gowall conversions in parallel using background processes
gowall convert "$PICDIR/$PIC" $THEME --output ~/Pictures/.lock_wallpaper --format png &
gowall convert "$PICDIR/$PIC2" $THEME --output ~/Pictures/.lock_wallpaper2 --format png &
gowall convert "$PICDIR/$PIC3" $THEME --output ~/Pictures/.lock_wallpaper3 --format png &

# Wait for all background processes to complete
wait

# Launch hyprlock with remaining arguments
hyprlock "$@"
