#!/bin/sh

BAT_LOW=15
BAT_CRITICAL=5

if [ "$1" = "--help" ]
then
    printf "
    Usage:
    \tbattery_check.sh warning%% hibernate%%

    Description:
    \tA script for notifying the user via dunst and logging when
    \tthe battery is low and the system is going to hibernate.
    \tCan be supplied arguments for the battery low warning and
    \thibernation percentage thresholds as the first and second arguments.

    \t Default behavior is to warn at 15% and hibernate at 5%."
    exit
fi

if [[ -n "$1" && -n "$2" && $1 -gt $2 ]]
then
    BAT_LOW=$1
    BAT_CRITICAL=$2
fi

acpi -b | awk -F'[,:%]' '{print $2, $3}' | {

	read -r status capacity
    echo Low threshold: $BAT_LOW, Hibernate threshold: $BAT_CRITICAL
    echo Status: $status, Capacity: $capacity

    if [ "$status" = Discharging -a "$capacity" -le $BAT_CRITICAL ]; then
        echo Battery critical threshold.
		dunstify -u critical "Critical battery threshold, hibernating..."
		logger "Critical battery threshold, hibernating..."
        sleep .5
		systemctl hibernate
        exit
	fi

    if [ "$status" = Discharging -a "$capacity" -le $BAT_LOW ]; then
        echo Battery low threshold.
		dunstify -u critical 'Battery low! System will hibernate at 5%.'
        logger 'Battery low! System will hibernate at 5%.'
        sleep .5
        light -S 15
		exit
    fi
}
