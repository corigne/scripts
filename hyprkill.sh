#!/bin/bash

if pid=$(hyprprop | jq '.pid'); then
  kill -9 $pid
else
  echo "Unable to get pid. Ensure 'hyprprop' is installed and WM is hyprland."
fi
