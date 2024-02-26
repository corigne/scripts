#!/bin/bash
DATE=(date '+%Y-%m-%d %H:%M:%S')
echo "Starting Easyeffects service at ${DATE}" | systemd-cat -p info

flatpak run com.github.wwmm.easyeffects --gapplication-service
