#!/bin/bash

# Post-game, restores previous monitor configs.
# Kills exterior monitors.
picom -b &
sleep 2
nvidia-settings --assign CurrentMetaMode="DP-4: 2560x1440_144 {ForceCompositionPipeline=On, AllowGSYNCCompatible=On}"
sleep 2
xrandr --output DP-2 --mode 2560x1440 --rate 60 --right-of DP-4
xrandr --output DP-0 --mode 3840x2160 --rate 60 --right-of DP-2
sleep 1
/home/nexus/.scripts/slideshow.sh &
