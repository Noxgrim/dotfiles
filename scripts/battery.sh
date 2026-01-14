#!/bin/bash
readonly DEV='BAT0'
capacity="$(<"/sys/class/power_supply/$DEV/capacity")"
status="$(<"/sys/class/power_supply/$DEV/status")"

if [ "$status" = Discharging ]; then
    if [ "$capacity" -lt 5 ]; then
        source /root/notify.sh
        logger "Critical battery threshold"
        notify -k batterywarn
        notify -u critical "Critical battery threshold" "Hibernating..."
        sleep 5
        systemctl hibernate -i
    elif [ "$capacity" -le 20 ]; then
        source /root/notify.sh
        notify -u critical -a 'noxgrim:power' -h "int:value:$capacity" "Low battery level: " % -n batterywarn
    fi
elif [ -e "/tmp/$USER/notifications/batterywarn" ]; then
    source /root/notify.sh
    notify -k batterywarn
fi
