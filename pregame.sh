#!/bin/bash

# Pre-game configuration script to allow for best NVIDIA performance.
# Kills exterior monitors.
pkill -9 picom &

nvidia-settings --assign CurrentMetaMode="DP-4: 2560x1440_60 {ForceCompositionPipeline=Off, AllowGSYNCCompatible=On}" &

xrandr --output DP-0 --off &
xrandr --output DP-2 --off &
