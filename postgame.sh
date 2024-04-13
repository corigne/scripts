#!/bin/bash

# Post-game, restores previous monitor configs.
# Kills exterior monitors.
picom -b &

sleep .05
nvidia-settings --assign CurrentMetaMode="DP-4: 2560x1440_144 {ForceCompositionPipeline=On, AllowGSYNCCompatible=On}"
sleep .05
xrandr --output DP-2 --mode 2560x1440 --rate 60 --right-of DP-4
sleep .05

$HOME/scripts/polybar_lch.sh &
$HOME/scripts/home_slideshow.sh &
