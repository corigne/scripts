#!/bin/sh
acpi -b | awk -F'[,:%]' '{print $2, $3}' | {
	read -r status capacity

	if [ "$status" = Discharging -a "$capacity" -lt 7 ]; then
		logger "Critical battery threshold, hibernating..."
		systemctl hibernate
	fi
}
