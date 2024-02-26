#!/bin/bash

# Term running polybar if any
killall -q polybar

# If all bars have ipc enabled...
# polybar-msg cmd quit

# Launch polybar, use def cfg in .config
#polybar offset 2>&1 | tee -a /tmp/polybar_offset.log & disown
polybar main 2>&1 | tee -a  /tmp/polybar.log & disown

echo "Polybar launched!"
