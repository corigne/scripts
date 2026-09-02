#!/bin/bash
while [ TRUE ]
do
  awww img $(ls $HOME/Pictures/animated_slideshow/* | shuf -n1)
  sleep 5m
done
