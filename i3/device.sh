#!/bin/bash

THIS="$0" # path to script
# X clients that should be ignored
WHITELIST=(ibus-x11 ibus-ui-gtk3 unity-settings-daemon notify-osd \
    gnome-screensaver mozc_renderer redshift-gtk skype skypeforlinux udiskie \
    nm-applet DiscordCanary Discord)
KILLLIST=( steam )

lock() {
    loginctl lock-session
    #gnome-screensaver-command -l
    #~/.i3/lock.sh
    #numlockx on
}

# the ugliest implementation of join you have ever seen...
join_comma() {
    local IFS=','
    echo "$*" | sed 's/,/, /g'
}

wait_for_backup() {
    local DID_NOTIFY=false
    while pgrep -cf 'borg'; do
        if [ "$DID_NOTIFY" = false ]; then
            notify-send -u low "Waiting for backup to finish…"
            DID_NOTIFY=true
        fi
        sleep '0.1'
    done
    while pgrep -cf "bash $HOME/.local/share/backup/backup.sh"; do
        if [ "$DID_NOTIFY" = false ]; then
            notify-send -u low "Waiting for backup to finish…"
            DID_NOTIFY=true
        fi
        sleep '0.1'
    done
}

close_firefox() {
    local WIN_IDS
    WIN_IDS="$(xdotool search --class "firefox")"
    while [ -n "$WIN_IDS" ]; do
        for ID in $WIN_IDS; do
            if xprop -id "$ID" | grep -q '^WM_STATE(WM_STATE):'; then
                xdotool key --clearmodifiers --window "$ID" ctrl+q
                sleep 0.5 # Wait for FF instance to close
                break
            fi
        done
        WIN_IDS="$(xdotool search --class "firefox")"
    done
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
    close_firefox >/dev/null
    i3-msg '[class=".*"] kill' # close all windows
    wait_for_backup&
    while pgrep -f '/usr/bin/anki'; do sleep '0.1'; done # wait for anki to sync
    sleep '1' # Wait because my system is SO slow
    killall "${KILLLIST[@]}"
    if [ "$(countclients)" -gt 0 ]; then # there are clients that refuse to die
        i3-nagbar -t warning \
            -m "The following clients refused to close: $(listclients)" \
            -b 'Logout' 'i3-msg exit' \
            -b 'Shutdown' "/bin/bash '$THIS' shutdown_force" \
            -b 'Reboot' "/bin/bash '$THIS' reboot_force" \
            -b 'Cancel' "/bin/bash -c 'killall \"$THIS\"'" &
        i3-msg mode "device.force [SRL]" &
    fi
    while [ "$( countclients )" -gt 0 ]; do sleep '0.1'; done
    wait
    return 0
}

do_shutdown() {
    systemctl poweroff
#    /usr/bin/dbus-send --system --print-reply --dest="org.freedesktop.ConsoleKit" /org/freedesktop/ConsoleKit/Manager org.freedesktop.ConsoleKit.Manager.Stop
}

do_reboot() {
    systemctl reboot
#    /usr/bin/dbus-send --system --print-reply --dest="org.freedesktop.ConsoleKit" /org/freedesktop/ConsoleKit/Manager org.freedesktop.ConsoleKit.Manager.Restart
}

do_suspend() {
    systemctl suspend
#    /usr/bin/dbus-send --system --print-reply --dest="org.freedesktop.UPower" /org/freedesktop/UPower org.freedesktop.UPower.Suspend
}
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

print_possible_commands() {

    "$0" usage 2>&1 | tail +2 | cut -d\  -f3- |\
        sed 's/[{+}]//g;s/|/\n/g' | grep -o '^\w*\s*' | sort
    printf '\n'

    "$HOME/.i3/discord.sh" usage 2>&1 | tail +2 | cut -d\  -f2- |\
        sed 's/^\s*//;s/[,|]/\n/g' | sed 's/^/discord /'
    printf '\n'

    local OUTPUT_VARIANTS
    OUTPUT_VARIANTS="$("$HOME/.i3/volume.sh" usage 2>&1 | tail +3 | cut -d\  -f2- | sed 's/\(\[.*]\|{[^}]*}\)\s*//g')"$'\n'
    while grep -q '<' <<< "$OUTPUT_VARIANTS"; do
        OUTPUT_VARIANTS="$(sed '/<[^>]*>/{s/^\([^<]*\)<\([^|>]*\)>\(.*$\)/\1\2\3/;s/^\([^<]*\)<\([^|>]*\)|\([^>]*\)>\(.*\)/\1\2\4\n\1<\3>\4/}' <<< "$OUTPUT_VARIANTS")"$'\n'
    done
    head -n-1 <<< "${OUTPUT_VARIANTS//^/volume }"

    local OUTPUT_OPTIONS OUTPUT_VARIANTS=''
    OUTPUT_OPTIONS="$("$HOME/.i3/output_layout.sh" usage 2>&1 | tail +3 | cut -d\  -f2-)"$'\n'
    sed '/MHDL/{s/\s*\(MHDL.\|<[^>]*>\)\s*//g;s/$/ /}' <<< "$OUTPUT_OPTIONS" | sed 's/^/output /' | head -n-1
    printf '\n'

    eval  "$(grep '\<MONITORS=' "$HOME/.device_specific/monitor_names.sh" | sed 's/export/local/')"
    OUTPUT_VARIANTS+="${OUTPUT_OPTIONS//MHDL1/.}"

    for NR in $( seq "$MONITORS" ); do
        OUTPUT_VARIANTS+="$(sed -n '/MHDL1/s/MHDL1/'"$NR"'/p' <<< "$OUTPUT_OPTIONS")"$'\n'
    done

    OUTPUT_VARIANTS+="${OUTPUT_VARIANTS//MHDL2/.}"

    for NR in $( seq "$MONITORS" ); do
        OUTPUT_VARIANTS+="$(sed -n '/MHDL2/s/MHDL2/'"$NR"'/p' <<< "$OUTPUT_VARIANTS")"$'\n'
    done
    while grep -q '<' <<< "$OUTPUT_VARIANTS"; do
        OUTPUT_VARIANTS="$(sed '/<[^>]*>/{s/^\([^<]*\)<\([^|>]*\)>/\1\2/;s/^\([^<]*\)<\([^|>]*\)|\([^>]*\)>/\1\2\n\1<\3>/}' <<< "$OUTPUT_VARIANTS")"$'\n'
    done
    sed 's/^/output /;/\([0-9.]\)[^0-9.]*\1/d;/MHDL2/d' <<< "$OUTPUT_VARIANTS" | sort | uniq | tail +2
    printf '\n'
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
            notify-send "Invalid format: '$FMT'"
            exit 1
        fi
        echo $((S+60*M+3600*H+86400*D))
    fi
}

schedule_cmd() {
    DIR='/tmp/noxgrim/device_scheduled'
    [ ! -d "$DIR" ] && mkdir -p "$DIR"

    CMD="${1-}"
    if [ -z "$CMD" ]; then
        CMD="$({ find "$DIR" -type f -printf %f | grep . && printf '\n'
                 print_possible_commands
             } | rofi -theme solarized -dmenu -i -async-pre-read 0 -multi⁻select -p "Schedule what" | tr '\n' ' ')"
        if [ -z "$CMD" ]; then
            return
        fi
    fi
    CMD="$(sed 's/\([^%]\|^\)%\([^%]\|$\)/\1 \2/g;s/%\(%\+\)/\1/g' <<< "$CMD")"
    DIRTY_TIME="${2-}"

    if [ -z "$DIRTY_TIME" ]; then
        DIRTY_TIME="$(rofi -theme solarized -dmenu -i -p "Schedule '$CMD' in")"
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
    notify-send -u low "$(printf "Schulded '%s' in %d:%02d:%02d" "$CMD" "$H" "$M" "$S")" "($DATE)"

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
    xargs "$0" <<< "$CMD"
    )& disown && echo "$! $SECS" > "$DIR/$CMD"
}


while [ $# -gt 0 ]; do
case "$1" in
    schedule)
        if [ -n "${2-}" ]; then
            schedule_cmd "$2"
            shift 1
        else
            echo "Which command?" >&2
            exit
        fi
        ;;
    schedule_what)
        schedule_cmd
        ;;
    schedule_at|schedule_in)
        if [ -n "${2-}" ] || [ -n "${3-}" ]; then
            schedule_cmd "$3" "$2"
            shift 2
        else
            echo "Which command and when?" >&2
            exit
        fi
        ;;
    execute_what)
        CMD="$( print_possible_commands | rofi -theme solarized -dmenu -i -async-pre-read 0 -multi-select -p "Execute device command" | tr '\n' ' ')"
        if [ -z "$CMD" ]; then
            return
        fi
        xargs "$0" <<< "$CMD"
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
    suspend|sleep)
        wait_for_backup; do_suspend
        ;;
    hibernate)
        wait_for_backup; hibernate
        ;;
    hybrid)
        wait_for_backup; hybrid
        ;;
    reboot)
        killapps; do_reboot
        ;;
    reboot_force)
        do_reboot
        ;;
    shutdown)
        killapps; do_shutdown
        ;;
    shutdown_force)
        do_shutdown
        ;;
    list_clients)
        listclients
        ;;
    count_clients)
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
    output)
        shift 1
        "$HOME/.i3/output_layout.sh" "${@:1:3}"
        if [ -x "$HOME/.device_specific/wallpaper_command.sh" ]; then
            "$HOME/.device_specific/wallpaper_command.sh"
        else
            find "$HOME" -maxdepth 1 -iname '.wallpaper*' -print0 | sort -z | xargs -0 feh --bg-scale
        fi
        shift 2
        ;;
    volume)
        shift 1
        "$HOME/.i3/volume.sh" "${@:1:3}"
        shift 2
        ;;
    discord)
        "$HOME/.i3/discord.sh" "$2"
        shift
        ;;
    dpms_off)
            if xset q | grep -q "DPMS is Enabled"; then
                notify-send -u low "Disabled DPMS"
            fi
            xset s off -dpms
        ;;
    dpms_of)
            if ! xset q | grep -q "DPMS is Enabled"; then
                notify-send -u low "Enabled DPMS"
            fi
            xset s off -dpms
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
        DIR='/tmp/noxgrim/'
        [ -d "$DIR" ] && mkdir "$DIR"
        xdotool getmouselocation --shell > "$DIR/mouse"
        xdotool mousemove 9001 9001
        xinput | grep 'slave\s*pointer' | grep -vi 'virtual' | grep -oP '(?<=id=)\d+' | while read -r ID; do
            xinput set-prop "$ID" "Device Enabled" 0
        done
        ;;
    mouse_on)
        DIR='/tmp/noxgrim/'
        if [ -f "$DIR/mouse" ]; then
        (
            source "$DIR/mouse"
            xdotool mousemove "$X" "$Y"
        )
            rm "$DIR/mouse"
        fi
        xinput | grep 'slave\s*pointer' | grep -vi 'virtual' | grep -oP '(?<=id=)\d+' | while read -r ID; do
            xinput set-prop "$ID" "Device Enabled" 1
        done
        ;;
    mouse_toggle)
        DIR='/tmp/noxgrim/'
        [ -d "$DIR" ] && mkdir "$DIR"
        if [ -f "$DIR/mouse" ]; then
        (
            source "$DIR/mouse"
            xdotool mousemove "$X" "$Y"
        )
            rm "$DIR/mouse"
            SETTING=1
        else
            SETTING=0
        fi
        xinput | grep 'slave\s*pointer' | grep -vi 'virtual' | grep -oP '(?<=id=)\d+' | while read -r ID; do
            xinput set-prop "$ID" "Device Enabled" "$SETTING"
        done
        ;;
    list_all_commands)
        print_possible_commands | sed '/\<\(\(output\|discord\)\>.*\|volume\)\s\+$/d;/^\s*$/d'
        ;;
    *) {
        echo "Unknown command: $1"
        echo "Usage: $0 {lock|logout|logout_force|suspend/sleep|hibernate|hybrid|reboot|reboot_force|shutdown|shutdown_force}+"
        echo "Usage: $0 {notify_pause|notify_resume|screen_off|output 3ARGS|volume 2ARGS|discord ARG|dpms_toggle|dpms_on|dpms_off|mouse_toggle|mouse_off|mouse_on}+"
        echo "Usage: $0 {list_all_commands|list_clients|count_clients}+"
        echo "Usage: $0 schedule {<command>|'<commands>'}"
        echo "Usage: $0 schedule_at |schedule_in <time> {<command>|'<commands>'|schedule_in <time> <command>%%<command>…}"
        echo "Usage: $0 schedule_what|execute_what"
    } >&2
        exit 2
esac
shift 1
done

exit 0
