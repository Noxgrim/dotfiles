#!/bin/bash

THIS="$(readlink -f "$(command -v "$0")")" # path to script
TDIR="$(dirname "$THIS")"
SUSPEND_ACTION='suspend'
HIBERNATE_ACTION='hibernate'
SSV_TICK_LENGTH=30
SSV_DIM_TICKS=2
SSV_OFF_TICKS=4

# shellcheck disable=SC1091
source "$TDIR/notify.sh"

lock() {
    loginctl lock-session
}

# the ugliest implementation of join you have ever seen...
join_comma() {
    printf ', %s' "$@" | cut -c3-
}

check_for_backup() {
    if systemctl is-active backup.service -q; then
        notify -u low "Waiting for backup to finish…" -a '[system]'
        sleep 3
    fi
}


list_usb() {
    local LSUSB ID F
    LSUSB="$(lsusb)"
    for F in /sys/bus/usb/devices/*; do
        ID="$(cat "$F/idVendor" 2>/dev/null):$(cat "$F/idProduct" 2>/dev/null)"
        echo "$(grep "$ID" -m 1 <<< "$LSUSB")  $F"
    done | grep -v Linux
}

reset_usb() {
    local -a DEV_NAMES
    local USBS USB DEV_FILES=""
    USBS="$(list_usb)"
    if [ $# = 0 ]; then
        mapfile -t DEV_NAMES < "$SCRIPT_ROOT/data/shared/usb_data"
    else
        DEV_NAMES=( "$@" )
    fi
    for PATTERN in "${DEV_NAMES[@]}"; do
        USB="$(grep -F "$PATTERN" -m1 <<< "$USBS")"
        if [ -n "$USB" ]; then
            DEV_FILES="$DEV_FILES ${USB##*/}"
        fi
    done
    DEV_FILES="${DEV_FILES:1}"
    if [ -n "$DEV_FILES" ]; then
        echo "reset_usb $DEV_FILES" > /tmp/"$USER"/service
    fi
}


should_screen_save() {
    if [ -e "/tmp/$USER/state/wokeup" ] && [ -e "/tmp/$USER/state/locked" ]; then
        return 0
    fi
    if [ "$(loginctl show-session --property=PreparingForSleep | cut -d= -f2)" == 'yes' ]; then
        return 1
    fi
    if ! xset q | grep -q "DPMS is Enabled"; then
        return 1
    fi
    if [ -d "/tmp/$USER/ssuspend" ] && find "/tmp/$USER/ssuspend" -mindepth 1 -maxdepth 1 -amin -1 | read -r; then
        xset dpms 0 0 0
        local OFFSEC="$((SSV_TICK_LENGTH*SSV_OFF_TICKS))"
        xset dpms "$OFFSEC" "$OFFSEC" "$OFFSEC"
        return 1
    fi
    find "/tmp/$USER/ssuspend" -mindepth 1 -maxdepth 1 -amin +1 -delete
    return 0
}

screen_save_untick() {
    [ -d "/tmp/$USER/" ] || mkdir -p "/tmp/$USER/"
    local TICK_FILE="/tmp/$USER/ssuspend.tick"

    local -i TICKS
    TICKS="$(cat "$TICK_FILE" 2>/dev/null || echo 0)"

    if [ $TICKS -ge 1 ]; then
        if [ -f "/tmp/$USER/state/locked" ] && [ -f "/tmp/$USER/state/wokeup" ]; then
            notify -a noxgrim:generic_bar -u critical ' ' -t 1
        fi
    fi
    if [ $TICKS -ge $SSV_DIM_TICKS ]; then
        call brightness restore 20&
    fi
    echo "0" > "$TICK_FILE"
    wait
}

screen_save_tick() {
    [ -d "/tmp/$USER/" ] || mkdir -p "/tmp/$USER/"
    local TICK_FILE="/tmp/$USER/ssuspend.tick"

    local -i TICKS
    local WAKEUP_STATE=none WAKEUP_STATE_PROGRESSIVE=noning
    TICKS="$(cat "$TICK_FILE" || echo 0)"

    if should_screen_save; then
        TICKS="$((TICKS+1))"
        if [ $TICKS -ge 1 ] && [ -f "/tmp/$USER/state/locked" ] && [ -f "/tmp/$USER/state/wokeup" ]; then
            if [ -f "/tmp/$USER/state/user_suspended" ]; then
                WAKEUP_STATE=suspend
                WAKEUP_STATE_PROGRESSIVE=suspending
            elif [ -f "/tmp/$USER/state/user_hibernated" ]; then
                WAKEUP_STATE=hibernate
                WAKEUP_STATE_PROGRESSIVE=hibernating
            elif [ -f "/tmp/$USER/state/system_sleeped" ]; then
                WAKEUP_STATE=suspend
                WAKEUP_STATE_PROGRESSIVE="system initiated suspending"
            else
                WAKEUP_STATE=suspend
                WAKEUP_STATE_PROGRESSIVE="system(?) initiated suspending"
            fi
            if [ "$WAKEUP_STATE" != none ]; then
                local -a NARGS
                [ "$TICKS" -gt $SSV_OFF_TICKS ] && NARGS=( -t 1 )
                reset_usb
                notify -a noxgrim:generic_bar -u critical 'No input!' \
                    "${WAKEUP_STATE_PROGRESSIVE^} again in $((SSV_TICK_LENGTH*(SSV_OFF_TICKS-TICKS)))s" \
                    -h "int:value:$((25*(SSV_OFF_TICKS-TICKS)))" "${NARGS[@]}"
            fi
        fi
        if [ $TICKS -ge $SSV_DIM_TICKS ]; then
            if [ "$(call brightness get 2>&1 | cut -d@ -f2 | sort -n | tail -n1)" -gt 1 ]; then
                call brightness save set 1 5000&
            fi
            if [ $TICKS -ge $SSV_OFF_TICKS ] && [ -f "/tmp/$USER/state/locked" ] && [ -f "/tmp/$USER/state/wokeup" ]; then
                call "$WAKEUP_STATE"
            fi
        fi
    else
        TICKS=0
    fi
    echo "$TICKS" > "$TICK_FILE"
    wait
}

post_wakeup() {
    [ -d '/tmp/'"$USER"'/state' ] || mkdir -p '/tmp/'"$USER"'/state'
    touch '/tmp/'"$USER"'/state/wokeup'
    xset s reset
    call reset_usb
    sleep 1s # reset is async
    call action reset_xinput
}


# shellcheck disable=SC2317
close_firefox() {
    local WIN_IDS
    WIN_IDS="$(xdotool search --class "librewolf") $(xdotool search --class "firefox")"
    while [ "$WIN_IDS" != ' ' ]; do
        for ID in $WIN_IDS; do
            if xprop -id "$ID" | grep -q '^WM_STATE(WM_STATE):'; then
                xdotool key --clearmodifiers --window "$ID" ctrl+q
                sleep 0.5 # Wait for FF instance to close
                break
            fi
        done
        WIN_IDS="$(xdotool search --class "librewolf") $(xdotool search --class "firefox")"
    done
}

listclients() {
    if ! ${SHUTDOWN_DATA-false}; then
        # See killapps for documentation
        #shellcheck disable=1091
        source "$SCRIPT_ROOT/data/shared/shutdown_data.sh"
    fi
    unset CLIENTS
    declare -Ag CLIENTS
    while IFS=\" read -r ID A _ B _; do
        PATTERN='"'"$A"'" "'"$B"'"'
        PATTERN="${PATTERN,,}"
        if "${IGNORELIST["$PATTERN"]-false}"; then
            continue
        fi
        for IGNORED in "${IGNORELIST_REGEX[@]}"; do
            if [[ "$PATTERN" =~ $IGNORED ]]; then
                continue 2
            fi
        done
        if [ -n "$B" ]; then
            NAME="$B"
        elif [ -n "$A" ]; then
            NAME="$A"
        else
            NAME="[unknown:${ID%% }]"
        fi
        CLIENTS["${NAME,,}"]=""
        "${1-false}" && echo "$ID \"$A\" \"$B\""
    done < <(xwininfo -root -tree -int |\
        sed '/^xwininfo:/d;
             /^\s*$/d;
             /^\s*\(Root\|Parent\) window id:/d;
             /child\(ren\)\?:$/d;
             :loop
               /  -\?[0-9]*x-\?[0-9]*+-\?[0-9]*+-\?[0-9]*  +-\?[0-9]*+-\?[0-9]*$/b end;
               N;s/\n//g;
               b loop;
             :end
               s///
               s/^\s*//
               /^[0-9]* (has no name):/d;
               /()$/d;
               s/^\s*\([0-9]*\).*(\([^)]*\))$/\1 \2/;')
    "${1-false}" || join_comma "${!CLIENTS[@]}"
}

# shellcheck disable=SC2317
waitclientcleanup() {
    for CLIENT in "${WAITLIST[@]}"; do
        #shellcheck disable=2086
        while pgrep $CLIENT; do sleep 0.1; done
    done
}

clientsrunning() {
    listclients >& /dev/null
    test ${#CLIENTS[@]} -gt 0
    return $?
}

killapps() {
    if ! ${SHUTDOWN_DATA-false}; then
        # Should contain a few varibales
        # SHUTDOWN_DATA=true
        # IGNORELIST_REGEX # array with regex against '"class" "class"' pattern
        #   e.g. '"[^"]*" "i3bar"' (case insensitive)
        # IGNORELIST # asso. array: strings, value always 'true' against pattern
        #   e.g. IGNORELIST['"i3-frame" "i3-frame"']=true (case insensitive)
        # WAITLIST # array: each value arguments for pgrep
        #   e.g. "-f '/bin/bash'"
        # KILLLIST # array: each value process name to kill
        #   e.g. 'firefox'
        #shellcheck disable=1091
        source "$SCRIPT_ROOT/data/shared/shutdown_data.sh"
    fi
    check_for_backup&
    export -f close_firefox waitclientcleanup
    timeout 4 bash -c close_firefox # Wait at most 4 seconds
    i3-msg '[class=".*"] kill' # close all windows
    killall "${KILLLIST[@]}"
    sleep '1' # Wait because my system is SO slow
    if clientsrunning; then # there are clients that refuse to die
        i3-msg mode "device.force [SRL[xc]]"
    fi
    barpid=""
    N=0
    while clientsrunning; do
        # canceled?
        if [ -n "$barpid" ] && [ ! -e "/proc/$barpid" ]; then
            wait
            return 1
        fi

        if [ "$((N%50))" = 0 ]; then
            [ -n "$barpid" ] && kill "$barpid"
            i3-nagbar -t warning \
                -m "The following clients refused to close: $(join_comma "${!CLIENTS[@]}")" \
                -B 'Logout' "/bin/bash '$THIS' logout_force" \
                -B 'Shutdown' "/bin/bash '$THIS' shutdown_force" \
                -B 'Reboot' "/bin/bash '$THIS' reboot_force" & disown
            barpid="$!"
        fi
        sleep 0.1
        N="$((N+1))"
    done
    wait
    timeout 30 bash -c waitclientcleanup # Wait at most 30 seconds
    return 0
}

do_shutdown() {
    systemctl poweroff
}

do_reboot() {
    systemctl reboot
}

announce_hibernate() {
    [ -d '/tmp/'"$USER"'/state' ] || mkdir -p '/tmp/'"$USER"'/state'
    touch '/tmp/'"$USER"'/state/user_hibernated'
}

announce_suspend() {
    # tell the timers waking the PC up that they can suspend again
    [ -d '/tmp/'"$USER"'/state' ] || mkdir -p '/tmp/'"$USER"'/state'
    touch '/tmp/'"$USER"'/state/user_suspended'
}

do_suspend() {
    announce_suspend
    systemctl "$SUSPEND_ACTION"
}

hibernate() {
    announce_hibernate
    systemctl "$HIBERNATE_ACTION"
}

hybrid() {
    announce_suspend
    announce_hibernate
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

    find "$HOME/.device_specific/actions/" "$SCRIPT_ROOT/actions"  -type f -executable -printf %f\\n |\
        sed 's/\.sh$//g;s/^/action /' | sort -u
    printf '\n'

    "$TDIR/discord.sh" usage 2>&1 | tail +2 | cut -d\  -f2- |\
        sed 's/^\s*//;s/[,|]/\n/g' | sed 's/^/discord /'
    printf '\n'

    "$TDIR/brightness.sh" help 2>&1 |\
        sed 's/^\(\w\+\):.*/\1/;t;s/^\(\w\+\) .*/\1 /;t;d' | sed 's/^/brightness /'
    printf '\n'

    local OUTPUT_VARIANTS
    OUTPUT_VARIANTS="$("$TDIR/volume.sh" usage 2>&1 | tail +3 | cut -d\  -f2- | sed 's/\(\[.*]\|{[^}]*}\)\s*//g')"$'\n'
    while grep -q '<' <<< "$OUTPUT_VARIANTS"; do
        OUTPUT_VARIANTS="$(sed '/<[^>]*>/{s/^\([^<]*\)<\([^|>]*\)>\(.*$\)/\1\2\3/;s/^\([^<]*\)<\([^|>]*\)|\([^>]*\)>\(.*\)/\1\2\4\n\1<\3>\4/}' <<< "$OUTPUT_VARIANTS")"$'\n'
    done
    sed 's,^\s*,volume ,' <<< "${OUTPUT_VARIANTS}" | head -n-1

    local OUTPUT_OPTIONS OUTPUT_VARIANTS=''
    OUTPUT_OPTIONS="$("$TDIR/output_layout.sh" usage 2>&1 | tail +3 | cut -d\  -f2-)"$'\n'
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
    FMT="${FMT## }"
    FMT="${FMT%% }"

    [ -z "$FMT" ] && return

    [ -z "${FMT//[0-9]}" ] && FMT="${FMT}m"

    if ! grep -q '^[ 0-9smhd]*$' <<< "$FMT"; then
        # date format (fixed)
        FMT="$(date +%s -d "$FMT")"
        if [ -n "$FMT" ]; then
            NOW="$(date +%s)"
            FMT=$((FMT-NOW))
            if [ $FMT -lt 0 ]; then
                notify "Must not be a past date" -a '[system]'
                exit 1
            fi
            echo "$FMT"
        else
            notify "Invalid format" -a '[system]'
            exit 1
        fi
    else
        D="$(grep -oiP '^[0-9]+\s*(?=d)' <<< "$FMT")"; FMT="$(perl -pe 's/^[0-9]+\s*[dD]\s*//'<<<"$FMT")"
        H="$(grep -oiP '^[0-9]+\s*(?=h)' <<< "$FMT")"; FMT="$(perl -pe 's/^[0-9]+\s*[hH]\s*//'<<<"$FMT")"
        M="$(grep -oiP '^[0-9]+\s*(?=m)' <<< "$FMT")"; FMT="$(perl -pe 's/^[0-9]+\s*[mM]\s*//'<<<"$FMT")"
        S="$(grep -oiP '^[0-9]+\s*(?=s?)' <<< "$FMT")"; FMT="$(perl -pe 's/^[0-9]+\s*[sS]?\s*//'<<<"$FMT")"
        if [ -n "$FMT" ] || [ -z "$D" ] && [ -z "$H" ] && [ -z "$M" ] && [ -z "$S" ]; then
            notify "Invalid format: '$FMT'" -a '[system]'
            exit 1
        fi
        echo $((S+60*M+3600*H+86400*D))
    fi
}

schedule_systemd() {
    local SECS="$1"
    local NAME="$2"
    shift 2
    systemd-run --slice-inherit --timer-property=AccuracySec=1us --user -q \
        -u "$NAME" --on-calendar="$(date -d "now+$SECS seconds" -Iseconds |\
        sed 's/T/ /g;s/[+-][0-9][0-9]:[0-9][0-9]$//')" "env" "SCRIPT_ROOT=$SCRIPT_ROOT" "$0" "$@"
}

schedule_cmd() {
    DIR='/tmp/'"$USER"'/device_scheduled'
    [ ! -d "$DIR" ] && mkdir -p "$DIR"

    CMD="${1-}"
    if [ -z "$CMD" ]; then
        CMD="$({ find "$DIR" -type f -printf '%f\n' | grep . && printf '\n'
                 print_possible_commands
             } | rofi -theme solarized -dmenu -i -async-pre-read 0 -multi⁻select -p "Schedule what" | tr '\n' ' ')"
         CMD="${CMD## }"
         CMD="${CMD%% }"
         if [ -z "$CMD" ]; then
             return
         fi
    fi
    CMD="$(sed 's/\([^%]\|^\)%\([^%]\|$\)/\1 \2/g;s/%\(%\+\)/\1/g' <<< "$CMD")"
    DIRTY_TIME="${2-}"
    AT="${3-true}"

    if [ -z "$DIRTY_TIME" ]; then
        DIRTY_TIME="$(rofi -theme solarized -dmenu -i -p "Schedule '$CMD' in")"
    fi

    if [ "$DIRTY_TIME" != 'cancel' ]; then
        SECS="$(to_secs "$DIRTY_TIME")"
    else
        SECS=''
    fi

    PATH_NAME="$DIR/${CMD:0:256}"
    UNIT_NAME="_$(systemd-escape -p "${PATH_NAME}")"
    UNIT_NAME="${UNIT_NAME:0:244}" # 255 -"-<ID>" - ".service"
    if [ -e "$PATH_NAME" ]; then
        OLD_PID="$( grep -o '^[0-9]*' "$PATH_NAME")"
        if [ -z "$OLD_PID" ]; then
            [ "$(systemctl list-unit-files --user "$UNIT_NAME-0.timer"   | wc -l)" -gt 3 ] && systemctl --user stop "$UNIT_NAME-0.timer"
            [ "$(systemctl list-unit-files --user "$UNIT_NAME-1.timer"   | wc -l)" -gt 3 ] && systemctl --user stop "$UNIT_NAME-1.timer"
            [ "$(systemctl list-unit-files --user "$UNIT_NAME-5.timer"   | wc -l)" -gt 3 ] && systemctl --user stop "$UNIT_NAME-5.timer"
            [ "$(systemctl list-unit-files --user "$UNIT_NAME-0.service" | wc -l)" -gt 3 ] && systemctl --user stop "$UNIT_NAME-0.service"
            [ "$(systemctl list-unit-files --user "$UNIT_NAME-1.service" | wc -l)" -gt 3 ] && systemctl --user stop "$UNIT_NAME-1.service"
            [ "$(systemctl list-unit-files --user "$UNIT_NAME-5.service" | wc -l)" -gt 3 ] && systemctl --user stop "$UNIT_NAME-5.service"
        else
            kill -SIGTERM "$OLD_PID"
        fi
        rm "$PATH_NAME"
        [ -z "$SECS" ] && notify -u low "Canceled '$CMD'" -a '[system]'
    fi
    [ -z "$SECS" ] && exit

    H="$(bc <<< "$SECS / 3600")"
    M="$(bc <<< "$SECS % 3600 / 60")"
    S="$(bc <<< "$SECS % 60")"
    DATE=$(date +'%Y-%m-%d %H:%M:%S' --date="$SECS seconds")
    INTRUSIVE=false
    REMINDER_5_URG=low
    REMINDER_1_URG=low
    REMINDER_SET_URG=low
    case "$CMD" in
        # intrusive cases
        *lock*|*logout*|*suspend*|*sleep*|*hibernate*|*hybrid*|*reboot*|*shutdown*|*screen_off*)
        INTRUSIVE=true
            REMINDER_5_URG=normal
            REMINDER_1_URG=critical
            ;;
    esac
    if $INTRUSIVE && [ "$SECS" -le 60 ]; then
        REMINDER_SET_URG=critical
    elif $INTRUSIVE && [ "$SECS" -le 300 ]; then
        REMINDER_SET_URG=normal
    fi
    notify -u "$REMINDER_SET_URG" "$(printf "Schulded '%s' in %d:%02d:%02d" "$CMD" "$H" "$M" "$S")" "($DATE)" -a '[system]'
    if [ "$AT" = true ]; then
        if [ "$((SECS-300))" -gt 0 ]; then
            schedule_systemd "$((SECS-300))" "$UNIT_NAME-5" run notify -u "$REMINDER_5_URG" "5 minutes" "until scheduled '$CMD'" -a '[system]'
        fi
        if [ "$((SECS-60))" -gt 0 ]; then
            schedule_systemd "$((SECS-60))" "$UNIT_NAME-1" run notify -u "$REMINDER_1_URG" "1 minute" "until scheduled '$CMD'" -a '[system]' -t 55000
        fi
        # shellcheck disable=SC2086
        schedule_systemd "$SECS" "$UNIT_NAME-0" run rm -r "$PATH_NAME" ';' $CMD
        echo " $SECS ($UNIT_NAME)" > "$PATH_NAME"
    else
        (
        TIME=$SECS
        ALARM=$((TIME-300))
        if [ $ALARM -ge 0 ]; then
            sleep $ALARM
            notify -u "$REMINDER_5_URG" "5 minutes" "until scheduled '$CMD'" -a '[system]'
            TIME=300
        fi
        ALARM=$((TIME-60))
        if [ $ALARM -ge 0 ]; then
            sleep $ALARM
            notify -u "$REMINDER_1_URG" "1 minute" "until scheduled '$CMD'" -a '[system]'
            TIME=60
        fi
        sleep "$TIME"
        rm "$DIR/$CMD"
        xargs "$0" <<< "$CMD"
        )& disown && echo "$! $SECS" > "$PATH_NAME"
    fi
}

run() {
    case "$1" in
        notify) "$@";;
        *) execute "$@";;
    esac
}

call() {
    while [ $# -gt 0 ]; do
        case "$1" in
            ";") ;;
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
            schedule_at)
                if [ -n "${2-}" ] || [ -n "${3-}" ]; then
                    schedule_cmd "$3" "$2" 'true'
                    shift 2
                else
                    echo "Which command and when?" >&2
                    exit
                fi
                ;;
            schedule_in)
                if [ -n "${2-}" ] || [ -n "${3-}" ]; then
                    schedule_cmd "$3" "$2" 'false'
                    shift 2
                else
                    echo "Which command and when?" >&2
                    exit
                fi
                ;;
            _to_secs)
                to_secs "$2"
                shift
                ;;
            execute_what)
                local CMD
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
                killapps && i3-msg exit
                ;;
            logout_force)
                i3-msg exit
                ;;
            suspend|sleep)
                check_for_backup; do_suspend
                ;;
            hibernate)
                check_for_backup; hibernate
                ;;
            hybrid)
                check_for_backup; hybrid
                ;;
            reboot)
                killapps && do_reboot
                ;;
            reboot_force)
                do_reboot
                ;;
            shutdown)
                killapps && do_shutdown
                ;;
            shutdown_force)
                do_shutdown
                ;;
            list_clients)
                listclients true
                ;;
            count_clients)
                listclients >/dev/null
                echo "${#CLIENTS[@]}"
                ;;

            notify_pause)
                notify -t 2000 -u low "Paused notifications" -a '[system]'
                sleep 3
                killall -SIGUSR1 dunst
                ;;
            notify_resume)
                killall -SIGUSR2 dunst
                notify -t 2000 -u low "Resumed notifications" -a '[system]'
                ;;
            screen_off)
                screen_off
                ;;
            output)
                shift 1
                "$TDIR/output_layout.sh" "${@:1:3}"
                shift 3
                ;&
            wallpaper)
                if [ -x "$HOME/.device_specific/wallpaper_command.sh" ]; then
                    "$HOME/.device_specific/wallpaper_command.sh"
                elif [ -d "$HOME/Documents/.wallpaper" ]; then
                    "$SCRIPT_ROOT/scripts/wallpaper_command.sh"
                else
                    find "$HOME" -maxdepth 1 -iname '.wallpaper*' -print0 | sort -Rz | xargs -0 feh --bg-scale
                fi
                ;;
            wallpaper_arg)
                shift 1
                if [ -x "$HOME/.device_specific/wallpaper_command.sh" ]; then
                    "$HOME/.device_specific/wallpaper_command.sh" "$1"
                elif [ -d "$HOME/Documents/.wallpaper" ]; then
                    "$SCRIPT_ROOT/scripts/wallpaper_command.sh" "$1"
                else
                    find "$HOME" -maxdepth 1 -iname '.wallpaper*'"$1"'*' -print0 | sort -Rz | xargs -0 feh --bg-scale
                fi
                ;;
            volume)
                shift 1
                "$TDIR/volume.sh" "${@:1:3}"
                shift 2
                ;;
            discord)
                "$TDIR/discord.sh" "$2"
                shift
                ;;
            dpms_off)
                    if xset q | grep -q "DPMS is Enabled"; then
                        notify -u low "Disabled DPMS" -a '[system]'
                    fi
                    xset s off -dpms
                ;;
            dpms_on)
                    if ! xset q | grep -q "DPMS is Enabled"; then
                        notify -u low "Enabled DPMS" -a '[system]'
                    fi
                    xset s on +dpms
                ;;
            dpms_toggle)
                if xset q | grep -q "DPMS is Enabled"; then
                    xset s off -dpms
                    notify -u low "Disabled DPMS" -a '[system]'
                else
                    xset s on  +dpms
                    notify -u low "Enabled DPMS" -a '[system]'
                fi
                ;;
            keyboard_off)
                if [ "$2" != '!' ]; then
                    echo "DANGEROUS OPERATION! Append argument '!' to force!" >&2
                    break
                else
                    shift 1
                fi

                xinput | grep 'slave\s*keyboard' | grep -vi 'virtual' | grep -oP '(?<=id=)\d+' | while read -r ID; do
                    xinput set-prop "$ID" "Device Enabled" 0
                done
                ;;
            keyboard_on)
                xinput | grep 'slave\s*keyboard' | grep -vi 'virtual' | grep -oP '(?<=id=)\d+' | while read -r ID; do
                    xinput set-prop "$ID" "Device Enabled" 1
                done
                ;;
            mouse_off)
                local DIR='/tmp/'"$USER"'/'
                [ -d "$DIR" ] || mkdir -p "$DIR"
                xdotool getmouselocation --shell > "$DIR/mouse"
                xdotool mousemove 9001 9001
                xinput | grep 'slave\s*pointer' | grep -vi 'virtual' | grep -oP '(?<=id=)\d+' | while read -r ID; do
                    xinput set-prop "$ID" "Device Enabled" 0
                done
                ;;
            mouse_on)
                local DIR='/tmp/'"$USER"'/'
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
                local DIR='/tmp/'"$USER"'/' SETTING
                [ -d "$DIR" ] || mkdir -p "$DIR"
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
            check_for_backup)
                check_for_backup
                ;;
            screen_save_tick)
                screen_save_tick
                ;;
            screen_save_untick)
                screen_save_untick
                ;;
            run|run_as)
                local OLD="$USER"
                [ "$1" == run_as ] && export USER="$2" && shift 1
                shift 1
                local ARGS=()
                while [ -n "${1+"?"}" ] && [ "$1" != ';' ]; do
                    ARGS+=("$1")
                    shift 1
                done
                run "${ARGS[@]}"
                USER="$OLD"
                ;;
            action)
                if [ -x "$HOME/.device_specific/actions/$2.sh" ]; then
                    "$HOME/.device_specific/actions/$2.sh" &>/dev/null& disown
                elif [ -x "$SCRIPT_ROOT/actions/$2.sh" ]; then
                    "$SCRIPT_ROOT/actions/$2.sh" &>/dev/null& disown
                fi
                shift 1
                ;;
            brightness)
                shift
                shift "$(setsid "$TDIR/brightness.sh" report "$@" 3>&2 2>&1 1>&3)" 2>&1
                ;;
            brightness_reload)
                echo 'brightness reload' > /tmp/"$USER"/service
                ;;
            post_wakeup)
                post_wakeup
                ;;
            send_all)
                shopt -s lastpipe
                while xbindkeys -k  | sed -n '$ {s/\s*//g;s/Mod2+//;p}' | read -r C; do
                    local F; F="$(xdotool getwindowfocus)"
                    xdotool search --name "$2" | xargs -I{} xdotool windowfocus --sync {} key --window {} "$C"
                    xdotool windowfocus --sync "$F"
                done
                shift
                ;;
            list_usb)
                list_usb
                ;;
            reset_usb)
                reset_usb
                ;;
            reset_usb_args)
                shift 1
                local ARGS=()
                while [ -n "${1+"?"}" ] && [ "$1" != ';' ]; do
                    ARGS+=("'${1//"'"/"'\\''"}'")
                    shift 1
                done
                reset_usb "${ARGS[@]}"
                ;;
            none);;
            *) {
                echo "Unknown command: $1"
                echo "Usage: $0 {lock|logout|logout_force|suspend/sleep|hibernate|hybrid|reboot|reboot_force|shutdown|shutdown_force}+"
                echo "Usage: $0 {notify_pause|notify_resume|screen_off|output 3ARGS|brightness ARGS|brightness_reload|reset_usb|reset_usb_args ARGS|wallpaper|wallpaper_arg ARG|volume 2ARGS|discord ARG|dpms_toggle|dpms_on|dpms_off|mouse_toggle|mouse_off|mouse_on|keyboard_on|keyboard_off|screen_save_untick}+"
                echo "Usage: $0 {list_all_commands|list_clients|count_clients|check_for_backup}+"
                echo "Usage: $0 schedule {<command>|'<commands>'}"
                echo "Usage: $0 schedule_at |schedule_in <time> {<command>|'<commands>'|schedule_in <time> <command>%%<command>…}"
                echo "Usage: $0 schedule_what|execute_what"
                echo "Usage: $0 run ARSGS ;"
                echo "Usage: $0 run_as USERANDARSGS ;"
                echo "Usage: $0 action ACTION_NAME"
            } >&2
                exit 2
        esac
        shift 1
    done
}

# check for device specific overrides
[ -e "$HOME/.device_specific/device_override.sh" ] && source "$HOME/.device_specific/device_override.sh"

call "$@"
exit 0
