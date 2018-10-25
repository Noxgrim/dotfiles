#!/bin/bash


THIS="$(dirname "$0")/$0" # path to script
# X clients that should be ignored
WHITELIST=(ibus-x11 ibus-ui-gtk3 unity-settings-daemon notify-osd \
    gnome-screensaver mozc_renderer redshift-gtk skype skypeforlinux udiskie \
    nm-applet discord)
KILLLIST=( steam )
HOSTNAME=$(hostname)

lock() {
    true
    #gnome-screensaver-command -l
    #~/.i3/lock.sh
    #numlockx on
}

# the ugliest implementation of join you have ever seen...
join_comma() {
    local IFS=','
    echo "$*" | sed 's/,/, /g'
}

listclients() {
    declare -ag CLIENTS
    CLIENTS=()
    local INDEX=0
    while read LINE; do
        local CLIENT=`echo $LINE | sed -rn 's/^\S+\s+(.+)$/\1/p'`
        if [ -n "$CLIENT" ]; then
            for IGNORED in "${WHITELIST[@]}"; do
                # Use a regex to also allow non-$PATH programs (Yes, I mean you Skype!)
                if [ -n "$(echo $CLIENT | grep -P "(^|/)$IGNORED($|\s+)")" ]; then
                    continue 2; fi
            done
            CLIENTS[$INDEX]="$CLIENT"
            INDEX=$((INDEX + 1))
        fi
    done < <(xlsclients) # the loop somehow can't modify the variables
                         # if I just pipe this in...
    join_comma "${CLIENTS[@]}"
}

countclients() {
    listclients >& /dev/null
    echo ${#CLIENTS[@]}
}

killapps() {
    i3-msg '[class=".*"] kill' # close all windows
    while pgrep -f '/usr/bin/anki'; do sleep '0.1'; done # wait for anki to sync
    sleep '1' # Wait because my sytem is SO slow
    killall "${KILLLIST[@]}"
    if [ `countclients` -gt 0 ]; then # there are clients that refuse to die
        i3-nagbar -t warning \
            -m "The following clients refused to close: `listclients`" \
            -b 'Logout' 'i3-msg exit' \
            -b 'Shutdown' "/bin/bash $THIS shutdown_force" \
            -b 'Reboot' "/bin/bash $THIS reboot_force" &
        i3-msg mode "device.force [SRL]" &
    fi
    while [ `countclients` -gt 0 ]; do sleep '0.1'; done
    return 0
}

my_shutdown() {
    systemctl poweroff
}

my_reboot() {
    systemctl reboot
}

my_suspend() {
    systemctl suspend
}
#my_shutdown() {
#    /usr/bin/dbus-send --system --print-reply --dest="org.freedesktop.ConsoleKit" /org/freedesktop/ConsoleKit/Manager org.freedesktop.ConsoleKit.Manager.Stop
#}
#
#my_reboot() {
#    /usr/bin/dbus-send --system --print-reply --dest="org.freedesktop.ConsoleKit" /org/freedesktop/ConsoleKit/Manager org.freedesktop.ConsoleKit.Manager.Restart
#}
#
#my_suspend() {
#    /usr/bin/dbus-send --system --print-reply --dest="org.freedesktop.UPower" /org/freedesktop/UPower org.freedesktop.UPower.Suspend
#}

hibernate() {
    systemctl hibernate
}

hybrid() {
    systemctl hybrid-sleep
}

screen_off() {
    sleep 1 &&
    xset dpms force off
}

mon_rotate() {
    ACTIVE_MON="$(i3-msg -t get_workspaces | grep -Po '"focused":true.*?"output":"[^"]*' | grep -o '[^"]*$')"
    ACTIVE_WKS="$(i3-msg -t get_outputs |  grep -Po 'name":"'"$ACTIVE_MON"'".*?"current_workspace":"[^"]*' | grep -o '[^"]*$')"
    xrandr --output "$ACTIVE_MON" --rotate "$1"
    mon_relayout
    i3-msg workspace "$ACTIVE_WKS"
}

mon_relayout() {
    ~/.output-layout.sh layout
    source ~/.wallpaper_command.sh
}

mon_toggle1() {
    ~/.output-layout.sh 1
    source ~/.wallpaper_command.sh
}
mon_toggle2() {
    ~/.output-layout.sh 2
    source ~/.wallpaper_command.sh
}
mon_kill() {
    ~/.output-layout.sh kill
    source ~/.wallpaper_command.sh
}

for ARG in "$@"; do
case "$ARG" in
    lock)
        lock
        ;;
    logout)
        killapps; i3-msg exit
        ;;
    logout_force)
        i3-msg exit
        ;;
    suspend)
        my_suspend
        ;;
    hibernate)
        hibernate
        ;;
    hybrid)
        hybrid
        ;;
    reboot)
        killapps; my_reboot
        ;;
    reboot_force)
        my_reboot
        ;;
    shutdown)
        killapps; my_shutdown
        ;;
    shutdown_force)
        my_shutdown
        ;;
    listclients)
        listclients
        ;;
    countclients)
        countclients
        ;;

    notify_pause)
        notify-send -t 2 -u low "Paused notifications"
        sleep 3
        killall -SIGUSR1 dunst
        ;;
    notify_resume)
        killall -SIGUSR2 dunst
        notify-send -t 2 -u low "Resumed notifications"
        ;;
    screen_off)
        screen_off
        ;;
    output-right)
        mon_rotate left
        ;;
    output-left)
        mon_rotate right
        ;;
    output-down)
        mon_rotate normal
        ;;
    output-up)
        mon_rotate inverted
        ;;
    output-1)
        mon_toggle1
        ;;
    output-2)
        mon_toggle2
        ;;
    output-kill)
        mon_kill
        ;;
    dpms_toggle)
        if xset q | grep -q "DPMS is Enabled"; then
            xset s off -dpms
            notify-send -u low "Disabled DPMS"
        else
            xset s on  +dpms
            notify-send -u low "Enabled DPMS"
        fi
        ;;
    mouse_off)
        xdotool mousemove 9001 9001 &&
        xinput set-prop 15 "Device Enabled" 0 &&
        xinput set-prop 10 "Device Enabled" 0
        ;;
    mouse_on)
        xinput set-prop 15 "Device Enabled" 1 &&
        xinput set-prop 10 "Device Enabled" 1
        ;;
    *)
        echo "Usage: $0 {lock|logout|suspend|reboot|shutdown}"
        exit 2
esac
done

exit 0
