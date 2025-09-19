#!/bin/bash

BAT_LOW=20                      # BAT PERCENT AT WHICH DIM, POWER PROFILE CHANGE, AND DIM
BAT_CRITICAL=13                 # BAT PERCENT AT WHICH HIBERNATE
BAT_CHECK_INTERVAL_SEC=60       # INTERVAL SCRIPT CHECKS BATTERY LEVEL
                                ## VERY LOW VALUES MAY RESULT IN HIGHER BATTERY DRAIN

DIMMED=false
DIM_VALUE=15            # PERCENT BACKLIGHT WHEN DIMMED
DEFAULT_BRIGHTNESS=100  # DEFALT BRIGHTNESS PLACEHOLDER

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
                echo 'Battery low, dimming screen!' >&1

                sleep 1

                #HANDLE DIMMING
                if ! $DIMMED; then
                        export PRE_DIM_VALUE=$(light -G)
                fi
                if ! ($DIMMED && light -S $DIM_VALUE); then
                        echo "Warning: Failed to dim screen." >&2
                else
                        DIMMED=true
                fi

                # HANDLE POWER SAVINGS
                if ! tuned-adm profile laptop-battery-powersave; then
                        echo "Warning: unable to change tuned profile."
                fi

        else
                # RESET BACKLIGHT
                # POWER PROFILE RESTORATION HANDLED IN SEPPARATE SCRIPT...
                # SEE: ~/.config/user-acpid/ac-power-on for more info.
                if $DIMMED; then
                        DIMMED=false
                        if [ ! -z $PRE_DIM_VALUE ]; then
                                light -S $PRE_DIM_VALUE
                        else
                                light -S $DEFAULT_BRIGHTNESS
                        fi
                fi
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
