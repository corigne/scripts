#!/bin/bash

while read -r trg
do
        case $trg in linux) exit 0
        esac
done
/usr/bin/mkinitcpio -P

# xrandr --output DP-4 --mode 2560x1440 --rate 60 --right-of DP-2
# nvidia-settings --assign CurrentMetaMode="DP-2: 2560x1440_144 +0+0 {ForceCompositionPipeline=On, AllowGSYNCCompatible=On}, DP-4: 2560x1440_60 +2560+0 {ForceCompositionPipeline=On, AllowGSYNCCompatible=Off}"
