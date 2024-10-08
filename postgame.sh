#!/bin/bash

# Post-game, restores previous monitor configs.
# Kills exterior monitors.

xrandr --output DP-4 --mode 2560x1440 --rate 60 --right-of DP-2
nvidia-settings --assign CurrentMetaMode="DP-2: 2560x1440_144 +0+0 {ForceCompositionPipeline=On, AllowGSYNCCompatible=On}, DP-4: 2560x1440_60 +2560+0 {ForceCompositionPipeline=On, AllowGSYNCCompatible=Off}"

$HOME/Scripts/polybar_lch.sh &
$HOME/Scripts/home_slideshow.sh &
picom -b &
