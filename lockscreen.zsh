#!/bin/zsh
img=$(ls /home/nexus/Pictures/sfw/*.(png|jpg) | shuf -n 1)
i3lockmore --image-fill $img #--lock-icon
#i3lockmore --blur
