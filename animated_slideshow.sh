#!/bin/bash
while [ TRUE ]
do
  swww img $(ls $HOME/Pictures/animated_slideshow/* | shuf -n1)
  sleep 5m
done
