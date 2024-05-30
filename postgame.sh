#!/bin/bash

# Post-game, restores previous monitor configs.
# Kills exterior monitors.

nvidia-settings --assign CurrentMetaMode="DP-4: 2560x1440_144 {ForceCompositionPipeline=On, AllowGSYNCCompatible=On}"
sleep 0.05
xrandr --output DP-2 --mode 2560x1440 --rate 60 --right-of DP-4
sleep 0.05

picom -b &
$HOME/scripts/home_slideshow.sh &
$HOME/scripts/polybar_lch.sh &
