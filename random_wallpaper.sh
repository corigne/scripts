#!/bin/bash
PICTURE=$(find /home/nexus/Pictures/slideshow -type f | shuf -n 1)
feh --randomize --bg-fill $HOME/Pictures/slideshow/*
