#!/bin/bash

# Pre-game configuration script to allow for best NVIDIA performance.
# Kills exterior monitors.
pkill -9 picom &

xrandr --output DP-0 --off &
xrandr --output DP-4 --off &
xrandr --output DP-2 --mode 2560x1440 --rate 144
nvidia-settings --assign CurrentMetaMode="DP-2: 2560x1440_144 +0+0 {ForceCompositionPipeline=Off, AllowGSYNCCompatible=On}"
