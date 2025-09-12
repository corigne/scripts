#!/bin/bash

BAT_LOW=20
BAT_CRITICAL=15
BAT_CHECK_INTERVAL_SEC=60
DIMMED=false

check_battery () {

        local status=$1
        local capacity=$2

        if [ -z "$status" ] || [ -z "$capacity" ]
        then
                echo "Bad acpi read, no values returned." >&2
                return 1
        fi

        if [ "$status" = Discharging ] && [ "$capacity" -le $BAT_CRITICAL ]
        then
                dunstify -u critical "Critical battery threshold, hibernating..."
                echo "Critical battery threshold, hibernating..."
                sleep 5
                systemctl hibernate
        elif [ "$status" = Discharging ] && [ "$capacity" -le $BAT_LOW ]
        then
                dunstify -u critical "Battery low! System will hibernate at $BAT_CRITICAL%."
                echo 'Battery low!' >&1
                sleep .5
                if ! light -O; then
                        echo "Warning: Failed to save brightness" >&2
                fi
                if ! light -S 15; then
                        echo "Warning: Failed to dim screen" >&2
                else
                        DIMMED=true
                fi
                BAT_CHECK_INTERVAL_SEC=30
                if ! tuned-adm profile laptop-battery-powersave; then
                        echo "Warning: unable to change tuned profile to automatic selection."
                fi
        else
                $DIMMED && DIMMED=false && light -I
                BAT_CHECK_INTERVAL_SEC=60
        fi
        return 0
}

while [ true ]
do
        # get the battery status and capacity from acpi
        info=($(acpi -b | awk -F'[,:%]' '{print $2, $3}'))
        status=${info[0]}
        capacity=${info[1]}
        echo "Battery status '$status', capacity: $capacity%" >&1

        check_battery $status $capacity
        if [ $? -eq 1 ]
        then
                echo "$?: Bad Return from check_battery()." >&2
                exit 1
        fi
        sleep $BAT_CHECK_INTERVAL_SEC
done
trap 'echo "Exiting battery monitor..."; exit 0' INT TERM
