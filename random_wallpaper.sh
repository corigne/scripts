#!/bin/bash
PICTURE=$(find /home/nexus/pictures/slideshow -type f | shuf -n 1)
feh --randomize --bg-fill $HOME/pictures/slideshow/*
