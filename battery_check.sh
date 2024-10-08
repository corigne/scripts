#!/bin/sh

BAT_LOW=15
BAT_CRITICAL=5
BAT_CHECK_INTERVAL_SEC=30
DIMMED=false

check_battery () {

        local status=$1
        local capacity=$2

        if [ -z "$status" -o -z "$capacity" ]
        then
                echo "Bad acpi read, no values returned." >&2
                return 1
        fi

        if [ "$status" = Discharging -a "$capacity" -le $BAT_CRITICAL ]
        then
                dunstify -u critical "Critical battery threshold, hibernating..."
                echo "Critical battery threshold, hibernating..." >&1
                sleep .5
                systemctl hibernate
        elif [ "$status" = Discharging -a "$capacity" -le $BAT_LOW ]
        then
                dunstify -u critical 'Battery low! System will hibernate at 5%.'
                echo 'Battery low!' >&1
                sleep .5
                light -O
                light -S 15 && DIMMED=true
        else
                $DIMMED && DIMMED=false && light -I
        fi
        return 0
}

while [ true ]
do
        # get the battery status and capacity from acpi
        info=($(acpi -b | awk -F'[,:%]' '{print $2, $3}'))
        status=${info[0]}
        capacity=${info[1]}
        echo "[$(date)] Battery status '$status', capacity: $capacity%" >&1

        RET=$(check_battery $status $capacity)
        if [ "$RET" == 1 ]
        then
                echo "$RET: Bad Return from battery_check()." >&2
                exit 1
        fi
        sleep $BAT_CHECK_INTERVAL_SEC
done
