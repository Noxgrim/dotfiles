#!/bin/bash
source /root/notify.sh
acpi -b | sed 's/[^:]*:\s*\([^,]*\),\s*\([^%]*\)%.*/\1,\2/' | {
    IFS=, read -r status capacity

    if [ "$status" = Discharging ]; then
        if [ "$capacity" -lt 5 ]; then
            logger "Critical battery threshold"
            notify -k batterywarn
            notify -u critical "Critical battery threshold" "Hibernating..."
            sleep 5
            systemctl hibernate -i
        elif [ "$capacity" -le 20 ]; then
            notify -u critical -a 'noxgrim:power' -h "int:value:$capacity" "Low battery level: " % -n batterywarn
        fi
    elif [ -e "/tmp/$USER/notifications/batterywarn" ]; then
        notify -k batterywarn
    fi
}
