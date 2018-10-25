#!/bin/bash
source /home/noxgrim/.i3/notify.sh
acpi -b | awk -F'[,:%]' '{print $2, $3}' | {
    read -r status capacity

    if [ "$status" = Discharging ]; then
        if [ "$capacity" -lt 5 ]; then
            logger "Critical battery threshold"
            notify -u critical "'Critical battery threshold'" "Hibernating..."
            sleep 5
            systemctl hibernate
        elif [ "$capacity" -le 15 ]; then
            notify -u critical -a 'noxgrim:volume' -h "int:value:$capacity" "'Low battery level: '" %
        fi
    fi
}
