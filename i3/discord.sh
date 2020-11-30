#! /bin/bash
set -eu -o pipefail

case "$1" in
    invisible|offline)
        REL_LOC=-125
        ;;
    dnd|do-not-disturb)
        REL_LOC=-190
        ;;
    idle|away)
        REL_LOC=-245
        ;;
    online)
        REL_LOC=-290
        ;;
    mute)
        REL_LOC_Y=25
        REL_LOC_X=225
        ;;
    deafen)
        REL_LOC_Y=25
        REL_LOC_X=255
        ;;
    leave|disconnect)
        REL_LOC_Y=115
        REL_LOC_X=290
        ;;
    accept|join)
        REL_LOC_Y=230
        REL_LOC_X=155
        ;;
    reject|dismiss)
        REL_LOC_Y=230
        REL_LOC_X=80
        ;;
    update)
        REL_LOC_Y=25
        REL_LOC_X=110
        ;;
    go|go-away)
        set -- idle
        # shellcheck disable=SC1090
        . "$0"
        set -- mute
        # shellcheck disable=SC1090
        . "$0"
        exit
        ;;
    come|come-back)
        set -- online
        # shellcheck disable=SC1090
        . "$0"
        set -- mute
        # shellcheck disable=SC1090
        . "$0"
        exit
        ;;
    none);;
    usage);&
    *)
        echo 'Unknown command: '"${1:-}" >&2
        echo 'Use: invisible|offline,dnd|do-not-disturb,idle|away,online' >&2
        echo '     mute,deafen' >&2
        echo '     accept|join,reject|dismiss,leave|disconnect' >&2
        echo '     update' >&2
        echo '     go|go-away,come|come-back' >&2
        exit 1
        ;;
esac

DISCORD_WINDOWS="$(xdotool search --class "discord")"
for ID in $DISCORD_WINDOWS; do
    if xprop -id "$ID" | grep -q '^WM_STATE(WM_STATE):'; then
        eval "$(xdotool getwindowgeometry --shell "$ID" | sed 's/^/WIN_/')"
        eval "$(xdotool getmouselocation  --shell | sed 's/^/MOUSE_/')"
        WIN_ACTIVE="$(xdotool getactivewindow)"
        TAKE_FROM_SCRATCHPAD=false
        WAS_IN_SCRATCHPAD=$(xprop -id "$ID" | grep -q '^\s*window state: Withdrawn' && echo true || echo false)
        WAS_FULL_SCREEN="$(i3-msg -t get_tree | jq '..|select(.window? and .window_type? and .window_type and .window=='"$WIN_ACTIVE"')|.fullscreen_mode==1')"

        if "${NOT_CALCED_OFF_SCREEN:-true}"; then
            WIN_NE_OFFSCREEN=true
            WIN_NW_OFFSCREEN=true
            WIN_SE_OFFSCREEN=true
            WIN_SW_OFFSCREEN=true
            WIN_SE_X="$((WIN_X+WIN_WIDTH))"
            WIN_SE_Y="$((WIN_Y+WIN_HEIGHT))"
            CORNERS_OFFSCREEN=4
            # Is the window offscreen (i.e. do we have to move it to be able to click it properly)?
            while read -r XRANDR_LINE && [ $CORNERS_OFFSCREEN != 0 ]; do
                # shellcheck disable=2001
                eval "$(sed 's/\([0-9]*\)[^x]*x\([0-9]*\)[^+]*+\([0-9]*\)+\([0-9]*\)/MON_WIDTH="\1";MON_HEIGHT="\2";MON_X="\3";MON_Y="\4";/' <<< "$XRANDR_LINE")"
                if "$WIN_NE_OFFSCREEN" && ((WIN_X>=MON_X&&WIN_X<(MON_X+MON_WIDTH)&&WIN_Y>=MON_Y&&WIN_Y<(MON_Y+MON_HEIGHT))); then
                    WIN_NE_OFFSCREEN=false
                    ((CORNERS_OFFSCREEN--))
                fi
                if "$WIN_NW_OFFSCREEN" && ((WIN_SE_X>=MON_X&&WIN_SE_X<(MON_X+MON_WIDTH)&&WIN_Y>=MON_Y&&WIN_Y<(MON_Y+MON_HEIGHT))); then
                    WIN_NW_OFFSCREEN=false
                    ((CORNERS_OFFSCREEN--))
                fi
                if "$WIN_SE_OFFSCREEN" && ((WIN_X>=MON_X&&WIN_X<(MON_X+MON_WIDTH)&&WIN_SE_Y>=MON_Y&&WIN_SE_Y<(MON_Y+MON_HEIGHT))); then
                    WIN_SE_OFFSCREEN=false
                    ((CORNERS_OFFSCREEN--))
                fi
                if "$WIN_SW_OFFSCREEN" && ((WIN_SE_X>=MON_X&&WIN_SE_X<(MON_X+MON_WIDTH)&&WIN_SE_Y>=MON_Y&&WIN_SE_Y<(MON_Y+MON_HEIGHT))); then
                    WIN_SW_OFFSCREEN=false
                    ((CORNERS_OFFSCREEN--))
                fi
            done < <(xrandr --listactivemonitors | tail +2 | cut -d':' -f2- | cut -d' ' -f3)
            NOT_CALCED_OFF_SCREEN=false
        fi
        if [ "$CORNERS_OFFSCREEN" -gt 0 ]; then
            if [ "$WAS_IN_SCRATCHPAD" = true ]; then
                TAKE_FROM_SCRATCHPAD=true
                xdotool windowactivate --sync "$ID"
            fi
            xdotool windowmove --sync "$ID"   "$MON_X" "$MON_Y"
        fi

        case "$1" in
            invisible|offline|dnd|do-not-disturb|idle|away|online)
                xdotool\
                    mousemove          --sync --clearmodifiers --window "$ID" -- 95 "$((WIN_HEIGHT-25))"\
                    click                     --clearmodifiers --window "$ID" 1\
                    mousemove_relative --sync --clearmodifiers                -- 0 "$REL_LOC"
                sleep 0.1
                xdotool\
                    click                     --clearmodifiers --window "$ID" 1
                ;;
            mute|deafen|leave|disconnect)
                xdotool\
                    mousemove          --sync --clearmodifiers --window "$ID" -- "$REL_LOC_X" "$((WIN_HEIGHT-REL_LOC_Y))"\
                    click                     --clearmodifiers --window "$ID" 1
                ;;
            accept|join|reject|dismiss)
                xdotool\
                    mousemove          --sync --clearmodifiers --window "$ID" -- "$REL_LOC_X" "$REL_LOC_Y"\
                    click                     --clearmodifiers --window "$ID" 1
                ;;
            update)
                xdotool\
                    mousemove          --sync --clearmodifiers --window "$ID" -- "$((WIN_WIDTH-REL_LOC_X))" "$REL_LOC_Y"\
                    click                     --clearmodifiers --window "$ID" 1
                ;;
        esac

        xdotool\
            mousemove "$MOUSE_X" "$MOUSE_Y"
        if [ "$WIN_X" -lt 0 ] || [ "$WIN_Y" -lt 0 ]; then
            xdotool windowmove --sync "$ID" "$WIN_X" "$WIN_Y"
        fi
        if [ "$TAKE_FROM_SCRATCHPAD" = true ]; then
            i3-msg  '[class="discord"]' scratchpad show > /dev/null
        fi
        xdotool windowactivate --sync "$WIN_ACTIVE"
        if [ "$WAS_FULL_SCREEN" = true ] && [ "$(i3-msg -t get_tree | jq 'recurse(.nodes[])|select(.window_type and .window=='"$WIN_ACTIVE"')|.fullscreen_mode==1')" = false ]; then
            i3-msg  '[id='"$WIN_ACTIVE"']' fullscreen
        fi
        break
    fi
done
