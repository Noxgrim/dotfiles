#!/bin/bash
source /root/notify.sh
acpi -b | sed 's/[^:]*:\s*\([^,]*\),\s*\([^%]*\)%.*/\1,\2/' | {
    IFS=, read -r status capacity

    if [ "$status" = Discharging ]; then
        if [ "$capacity" -lt 5 ]; then
            logger "Critical battery threshold"
            notify -u critical -a 'noxgrim:power' -h "int:value:$capacity" "Low battery level: " % -t 1
            notify -u critical "Critical battery threshold" "Hibernating..."
            sleep 5
            systemctl hibernate -i
        elif [ "$capacity" -le 15 ]; then
            notify -u critical -a 'noxgrim:power' -h "int:value:$capacity" "Low battery level: " %
        fi
    elif [ "$capacity" -le 17 ]; then
        notify -u critical -a 'noxgrim:power' -h "int:value:$capacity" "Low battery level: " % -t 1
    fi
}
