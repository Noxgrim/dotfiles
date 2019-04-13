#!/bin/bash


THIS="$0" # path to script
# X clients that should be ignored
WHITELIST=(ibus-x11 ibus-ui-gtk3 unity-settings-daemon notify-osd \
    gnome-screensaver mozc_renderer redshift-gtk skype skypeforlinux udiskie \
    nm-applet Discord)
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
    while read -r LINE; do
        CLIENT="$(sed -rn 's/^\S+\s+(.+)$/\1/p' <<< "$LINE")"
        if [ -n "$CLIENT" ]; then
            for IGNORED in "${WHITELIST[@]}"; do
                # Use a regex to also allow non-$PATH programs (Yes, I mean you Skype!)
                if grep -qP "(^|/)$IGNORED($|\s+)" <<< "$CLIENT"; then
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
    if [ "$(countclients)" -gt 0 ]; then # there are clients that refuse to die
        i3-nagbar -t warning \
            -m "The following clients refused to close: $(listclients)" \
            -b 'Logout' 'i3-msg exit' \
            -b 'Shutdown' "/bin/bash '$THIS' shutdown_force" \
            -b 'Reboot' "/bin/bash '$THIS' reboot_force" &
        i3-msg mode "device.force [SRL]" &
    fi
    while [ "$( countclients )" -gt 0 ]; do sleep '0.1'; done
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

to_secs() {
    FMT="$1"
    FMT="${FMT##*( )}"
    FMT="${FMT%%*( )}"

    [ -z "$FMT" ] && return


    if grep -q '[^ 0-9smhd]' <<< "$FMT"; then
        # date format (fixed)
        FMT="$(date +%s -d "$FMT")"
        if [ -n "$FMT" ]; then
            NOW="$(date +%s -d "$FMT")"
            FMT=$((FMT-NOW))
            if [ $FMT -lt 0 ]; then
                notify-send "Must not be a past date"
                exit 1
            fi
            echo "$FMT"
        else
            notify-send "Invalid format"
            exit 1
        fi
    else
        D="$(grep -oiP '^[0-9]+\s*(?=d)' <<< "$FMT")"; FMT="$(perl -pe 's/^[0-9]+\s*[dD]\s*//'<<<"$FMT")"
        H="$(grep -oiP '^[0-9]+\s*(?=h)' <<< "$FMT")"; FMT="$(perl -pe 's/^[0-9]+\s*[hH]\s*//'<<<"$FMT")"
        M="$(grep -oiP '^[0-9]+\s*(?=m)' <<< "$FMT")"; FMT="$(perl -pe 's/^[0-9]+\s*[mM]\s*//'<<<"$FMT")"
        S="$(grep -oiP '^[0-9]+\s*(?=s?)' <<< "$FMT")"; FMT="$(perl -pe 's/^[0-9]+\s*[sS]?\s*//'<<<"$FMT")"
        if [ -n "$FMT" ] || [ -z "$D" ] && [ -z "$H" ] && [ -z "$M" ] && [ -z "$S" ]; then
            notify-send "Invalid format"
            exit 1
        fi
        echo $((S+60*M+3600*H+86400*D))
    fi
}

schedule_cmd() {
    CMD="$1"
    DIRTY_TIME="$2"
    DIR='/tmp/noxgrim/device_scheduled'
    [ ! -d "$DIR" ] && mkdir -p "$DIR"

    if [ -z "$DIRTY_TIME" ]; then
        DIRTY_TIME="$(rofi -theme solarized_alpha -dmenu -i -p "Schedule '$CMD' in")"
    fi
    
    SECS="$(to_secs "$DIRTY_TIME")"

    if [ -e "$DIR/$CMD" ]; then
        OLD_PID="$( grep -o '^[0-9]*' "$DIR/$CMD")"
        kill -SIGTERM "$OLD_PID"
        rm "$DIR/$CMD"
        [ -z "$SECS" ] && notify-send -u low "Canceled '$CMD'"
    fi
    [ -z "$SECS" ] && exit

    H="$(bc <<< "$SECS / 3600")"
    M="$(bc <<< "$SECS % 3600 / 60")"
    S="$(bc <<< "$SECS % 60")"
    DATE=$(date +'%d.%m.%Y %H:%M:%S' --date="$SECS seconds")
    notify-send -u low "$(printf "Schulded '$CMD' in %d:%02d:%02d" "$H" "$M" "$S")" "($DATE)"

    (
    TIME=$SECS
    ALARM=$((TIME-300))
    if [ $ALARM -ge 0 ]; then
        sleep $ALARM
        notify-send -u low "5 minutes" "until scheduled '$CMD'"
        TIME=300
    fi
    ALARM=$((TIME-60))
    if [ $ALARM -ge 0 ]; then
        sleep $ALARM
        notify-send -u low "1 minute" "until scheduled '$CMD'"
        TIME=60
    fi
    sleep $TIME
    rm "$DIR/$CMD"
    "$0" $CMD
    )& disown && echo "$! $SECS" > "$DIR/$CMD"
}

while [ $# -gt 0 ]; do
case "$1" in
    schedule)
        if [ -n "$2" ]; then
            schedule_cmd "$2"
            shift 1
        else
            echo "Which command?"
        fi
        ;;
    schedule_at)
        if [ -n "$2" ]; then
            schedule_cmd "$2" "$3"
            shift 2
        else
            echo "Which command?"
        fi
        ;;
    lock)
        lock
        ;;
    logout)
        killapps; i3-msg exit
        ;;
    logout_force)
        i3-msg exit
        ;;
    sleep);&
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
        notify-send -t 2000 -u low "Paused notifications"
        sleep 3
        killall -SIGUSR1 dunst
        ;;
    notify_resume)
        killall -SIGUSR2 dunst
        notify-send -t 2000 -u low "Resumed notifications"
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
        echo "Usage: $0 {lock|logout|logout_force|suspend/sleep|hibernate|hybrid|reboot|reboot_force|shutdown|shutdown_force}+"
        echo "Usage: $0 {notify_pause|notify_resume|screen_off|output-{right|left|up|down|kill|1|2}|dpms_toggle|mouse_off|mouse_on}+"
        echo "Usage: $0 schedule {<command>|'<commands>'}"
        echo "Usage: $0 scheduleat {<command>|'<commands>'} <time>"
        exit 2
esac
shift 1
done

exit 0
