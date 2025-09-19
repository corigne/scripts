#!/bin/bash

swayidle -w \
    timeout 600 'swaylock -fi ~/Pictures/slideshow/$(ls ~/Pictures/sfw | shuf -n 1)' \
    timeout 610 'hyprctl dispatch dpms off' \
    resume 'hyprctl dispatch dpms on' \
    before-sleep 'playerctl pause; swaylock -fi ~/Pictures/slideshow/$(ls ~/Pictures/sfw | shuf -n 1)'
