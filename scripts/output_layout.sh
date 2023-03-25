#!/bin/bash
set -eu -o pipefail
exec 4>/var/tmp/monitor_script.lock || exit 1
flock 4 || exit 1

# shellcheck source=/home/noxgrim/.device_specific/monitor_names.sh
source "$HOME/.device_specific/monitor_names.sh"

#xrandr --setprovideroutputsource modesetting NVIDIA-0
#xrandr --dpi 96
XRANDR="$(xrandr)"
LAST_ACTIVE=
LAST_ACTIVE_SOURCE=
#LAST_ACTIVE_DEFAULT=

ACTIVE_MONITORS=0
for NO in $(seq $MONITORS); do
    eval "ACTIVE=1;
          MONITOR_${NO}_ACTIVE=1;
          MONITOR_${NO}_CONNECTED=1;
          if grep -qE ^\"\$MONITOR_${NO}_SOURCE\"' connected( [a-z]*)* \\(' <<< \"\$XRANDR\"; then
              MONITOR_${NO}_ACTIVE=
              ACTIVE=
          elif grep -qE ^\"\$MONITOR_${NO}_SOURCE\"' disconnected' <<< \"\$XRANDR\"; then
              MONITOR_${NO}_ACTIVE=
              MONITOR_${NO}_CONNECTED=
              ACTIVE=
          fi"
    if [ -n "$ACTIVE" ]; then
        ((ACTIVE_MONITORS+=1))
        LAST_ACTIVE="$NO"
        eval "LAST_ACTIVE_SOURCE=\"\$MONITOR_${NO}_SOURCE\""
        eval "LAST_ACTIVE_DEFAULT=\"\$MONITOR_${NO}_DEFAULT\""
    fi
    eval "grep -qE ^\"\$MONITOR_${NO}_SOURCE\"' connected primary' <<< \"\$XRANDR\" && PRIMARY=$NO || true"
done

declare -a MY_ARGS=("$@")
FOCUSED__NO=
for ((ARG_NO=0; ARG_NO < $#; ARG_NO++)); do
    if [ "${MY_ARGS[$ARG_NO]}" = . ]; then
        TARGET_SOURCE="$(i3-msg -t get_workspaces | jq 'map(select(.focused)) | .[0].output' -r)"
        [ -z "$FOCUSED__NO" ] && for NO in $(seq $MONITORS); do
            eval "SOURCE=\"\$MONITOR_${NO}_SOURCE\""
            if [ "$SOURCE" = "$TARGET_SOURCE" ]; then
                FOCUSED__NO="$NO"
                break
            fi
        done
        set -- "${@:1:$ARG_NO}" "$FOCUSED__NO" "${@:$((ARG_NO+2))}"
    fi
done
unset MY_ARGS
# I3_WORKSPACE="$(i3-msg -t get_workspaces | jq 'map(select(.focused)) | .[0].name' -r)"

pack() {
    local DATA='{}'
    for NO in $(seq $MONITORS); do
        eval "ACTIVE=\"\$MONITOR_${NO}_ACTIVE\";SOURCE=\"\$MONITOR_${NO}_SOURCE\";DEFAULT=\"\$MONITOR_${NO}_DEFAULT\""
        if [ -n "$ACTIVE" ]; then
            DATA="$(jq ".\"$SOURCE\" = {$(grep ^"$SOURCE" <<< "$XRANDR" | sed 's/^[^ ]*[^0-9]*\([0-9]\+\)x\([0-9]\+\)+\([0-9]\+\)+\([0-9]\+\).*$/"x":\3,"y":\4,"width":\1,"height":\2/')}" <<< "$DATA")"
        fi
    done
    python3 -- - "$@" << EOF
from typing import List
outputs = $DATA ;


def intersects(px: int, pw: int, qx: int, qw: int) -> bool:
    py = px + pw -1
    qy = qx + qw -1
    return px <= qx < py\
        or px <= qy < py\
        or px > qx and py < qy


def pack_around(output: str, all : bool = False ) -> List[str]:
    from sys import maxsize
    nearest_below=None
    nearest_below_dist=maxsize
    nearest_above=None
    nearest_above_dist=-maxsize
    nearest_right=None
    nearest_right_dist=maxsize
    nearest_left=None
    nearest_left_dist=-maxsize

    for key in outputs.keys():
        if key == output:
            continue
        # above/below
        if intersects(outputs[output]["x"], outputs[output]["width"], outputs[key]["x"], outputs[key]["width"]):
            dist = outputs[key]["y"] - outputs[output]["y"]
            if dist < 0:
                if not nearest_above or nearest_above_dist < dist:
                    nearest_above = key
                    nearest_above_dist = dist
            elif all and dist > 0:
                if not nearest_below or nearest_below_dist > dist:
                    nearest_below = key
                    nearest_below_dist = dist
        # left/right
        if intersects(outputs[output]["y"], outputs[output]["height"], outputs[key]["y"], outputs[key]["height"]):
            dist = outputs[key]["x"] - outputs[output]["x"]
            if dist < 0:
                if not nearest_left or nearest_left_dist < dist:
                    nearest_left = key
                    nearest_left_dist = dist
            elif all and dist > 0:
                if not nearest_right or nearest_right_dist > dist:
                    nearest_right = key
                    nearest_right_dist = dist
    ret = ["--output", output]
    if nearest_above:
        ret += [ "--below", nearest_above ]
    if nearest_left:
        ret += [ "--right-of", nearest_left ]
    if nearest_below:
        ret += [ "--output", nearest_below, "--below", output ]
    if nearest_right:
        ret += [ "--output", nearest_right, "--right-of", output ]
    return ret

import itertools
import sys
import subprocess
print(str(list(itertools.chain(['xrandr'] + sys.argv[1:], *[pack_around(i[0]) for i in sorted(sorted(outputs.items(), key=lambda i: i[1]["x"]), key=lambda i:i[1]["y"])]))))
subprocess.run(list(itertools.chain(['xrandr'] + sys.argv[1:], *[pack_around(i[0]) for i in sorted(sorted(outputs.items(), key=lambda i: i[1]["x"]), key=lambda i:i[1]["y"])])))
EOF
}

if [[ "$1" =~ ^[0-9]+$ ]]; then
    set -- "$2" "$1" ${3:+$3}
fi

case "$1" in
    default)
        LAST=
        for NO in $(seq $MONITORS); do
            eval "ACTIVE=\"\$MONITOR_${NO}_ACTIVE\";CONNECTED=\"\$MONITOR_${NO}_CONNECTED\";SOURCE=\"\$MONITOR_${NO}_SOURCE\";DEFAULT=\"\$MONITOR_${NO}_DEFAULT\""
            [ -z "$CONNECTED" ] && DEFAULT=off
            case "$DEFAULT" in
                off)
                    xrandr --output "$SOURCE" --off
                    ;;
                on)
                    if [ -z "$LAST" ]; then
                        xrandr --output "$SOURCE" --auto
                    else
                        xrandr --output "$SOURCE" --auto --right-of "$LAST"
                    fi
                    LAST="$SOURCE"
                    ;;
                primary)
                    if [ -z "$LAST" ]; then
                        xrandr --output "$SOURCE" --auto
                    else
                        xrandr --output "$SOURCE" --auto --right-of "$LAST"
                    fi
                    xrandr --output "$SOURCE" --primary
                    LAST="$SOURCE"
                    ;;
            esac
        done
        ;;
    pack)
        pack
        ;;
    all-on|allon)
        LAST=
        for NO in $(seq $MONITORS); do
            eval "ACTIVE=\"\$MONITOR_${NO}_ACTIVE\";CONNECTED=\"\$MONITOR_${NO}_CONNECTED\";SOURCE=\"\$MONITOR_${NO}_SOURCE\";DEFAULT=\"\$MONITOR_${NO}_DEFAULT\""
            [ -z "$CONNECTED" ] && continue
            if [ -z "$LAST" ]; then
                xrandr --output "$SOURCE" --auto
            else
                xrandr --output "$SOURCE" --auto --right-of "$LAST"
            fi
            LAST="$SOURCE"
            if [ "$DEFAULT" = primary ]; then
                xrandr --output "$SOURCE" --primary
            fi
        done
        ;;
    above)
        if [ "$2" -le "$MONITORS" ] && [ "$3" -le "$MONITORS" ]; then
            eval "ACTIVE_1=\"\$MONITOR_${2}_ACTIVE\";CONNECTED_1=\"\$MONITOR_${2}_CONNECTED\";SOURCE_1=\"\$MONITOR_${2}_SOURCE\";DEFAULT_1=\"\$MONITOR_${2}_DEFAULT\""
            eval "ACTIVE_2=\"\$MONITOR_${3}_ACTIVE\";CONNECTED_2=\"\$MONITOR_${3}_CONNECTED\";SOURCE_2=\"\$MONITOR_${3}_SOURCE\";DEFAULT_2=\"\$MONITOR_${3}_DEFAULT\""
            if [ -n "$ACTIVE_1" ]; then
                xrandr --output "$SOURCE_2" --below "$SOURCE_1" --auto
            elif [ -n "$ACTIVE_2" ]; then
                xrandr --output "$SOURCE_1" --above "$SOURCE_2" --auto
            fi
        fi
        ;;
    below)
        if [ "$2" -le "$MONITORS" ] && [ "$3" -le "$MONITORS" ]; then
            eval "ACTIVE_1=\"\$MONITOR_${2}_ACTIVE\";CONNECTED_1=\"\$MONITOR_${2}_CONNECTED\";SOURCE_1=\"\$MONITOR_${2}_SOURCE\";DEFAULT_1=\"\$MONITOR_${2}_DEFAULT\""
            eval "ACTIVE_2=\"\$MONITOR_${3}_ACTIVE\";CONNECTED_2=\"\$MONITOR_${3}_CONNECTED\";SOURCE_2=\"\$MONITOR_${3}_SOURCE\";DEFAULT_2=\"\$MONITOR_${3}_DEFAULT\""
            if [ -n "$ACTIVE_1" ]; then
                xrandr --output "$SOURCE_2" --above "$SOURCE_1" --auto
            elif [ -n "$ACTIVE_2" ]; then
                xrandr --output "$SOURCE_1" --below "$SOURCE_2" --auto
            fi
        fi
        ;;
    left-of|leftof)
        if [ "$2" -le "$MONITORS" ] && [ "$3" -le "$MONITORS" ]; then
            eval "ACTIVE_1=\"\$MONITOR_${2}_ACTIVE\";CONNECTED_1=\"\$MONITOR_${2}_CONNECTED\";SOURCE_1=\"\$MONITOR_${2}_SOURCE\";DEFAULT_1=\"\$MONITOR_${2}_DEFAULT\""
            eval "ACTIVE_2=\"\$MONITOR_${3}_ACTIVE\";CONNECTED_2=\"\$MONITOR_${3}_CONNECTED\";SOURCE_2=\"\$MONITOR_${3}_SOURCE\";DEFAULT_2=\"\$MONITOR_${3}_DEFAULT\""
            if [ -n "$ACTIVE_1" ]; then
                xrandr --output "$SOURCE_2" --right-of "$SOURCE_1" --auto
            elif [ -n "$ACTIVE_2" ]; then
                xrandr --output "$SOURCE_1" --left-of "$SOURCE_2" --auto
            fi
        fi
        ;;
    right-of|rightof)
        if [ "$2" -le "$MONITORS" ] && [ "$3" -le "$MONITORS" ]; then
            eval "ACTIVE_1=\"\$MONITOR_${2}_ACTIVE\";CONNECTED_1=\"\$MONITOR_${2}_CONNECTED\";SOURCE_1=\"\$MONITOR_${2}_SOURCE\";DEFAULT_1=\"\$MONITOR_${2}_DEFAULT\""
            eval "ACTIVE_2=\"\$MONITOR_${3}_ACTIVE\";CONNECTED_2=\"\$MONITOR_${3}_CONNECTED\";SOURCE_2=\"\$MONITOR_${3}_SOURCE\";DEFAULT_2=\"\$MONITOR_${3}_DEFAULT\""
            if [ -n "$ACTIVE_1" ]; then
                xrandr --output "$SOURCE_2" --left-of "$SOURCE_1" --auto
            elif [ -n "$ACTIVE_2" ]; then
                xrandr --output "$SOURCE_1" --right-of "$SOURCE_2" --auto
            fi
        fi
        ;;
    same-as|sameas)
        if [ "$2" -le "$MONITORS" ] && [ "$3" -le "$MONITORS" ]; then
            eval "ACTIVE_1=\"\$MONITOR_${2}_ACTIVE\";CONNECTED_1=\"\$MONITOR_${2}_CONNECTED\";SOURCE_1=\"\$MONITOR_${2}_SOURCE\";DEFAULT_1=\"\$MONITOR_${2}_DEFAULT\""
            eval "ACTIVE_2=\"\$MONITOR_${3}_ACTIVE\";CONNECTED_2=\"\$MONITOR_${3}_CONNECTED\";SOURCE_2=\"\$MONITOR_${3}_SOURCE\";DEFAULT_2=\"\$MONITOR_${3}_DEFAULT\""
            if [ -n "$ACTIVE_1" ]; then
                xrandr --output "$SOURCE_2" --same-as "$SOURCE_1" --auto
            elif [ -n "$ACTIVE_2" ]; then
                xrandr --output "$SOURCE_1" --same-as "$SOURCE_2" --auto
            fi
        fi
        ;;
    toggle)
        if [ "$2" -le "$MONITORS" ]; then
            eval "ACTIVE=\"\$MONITOR_${2}_ACTIVE\";CONNECTED=\"\$MONITOR_${2}_CONNECTED\";SOURCE=\"\$MONITOR_${2}_SOURCE\";DEFAULT=\"\$MONITOR_${2}_DEFAULT\""
            if [ -n "$ACTIVE" ]; then
                HARD_REDRAW=true
                if [ "$ACTIVE_MONITORS" -le 1 ]; then
                    "$HOME"/.i3/device.sh screen_off
                else
                    xrandr --output "$SOURCE" --off
                    if [ "$PRIMARY" = "$2" ]; then
                        for NO in $(seq $MONITORS); do
                            eval "ACTIVE=\"\$MONITOR_${NO}_ACTIVE\";CONNECTED=\"\$MONITOR_${NO}_CONNECTED\";SOURCE=\"\$MONITOR_${NO}_SOURCE\";DEFAULT=\"\$MONITOR_${NO}_DEFAULT\""
                            if [ -n "$ACTIVE" ] && [ "$NO" != "$2" ]; then
                                xrandr --output "$SOURCE" --primary
                                break
                            fi
                        done
                    fi
                fi
            elif [ -n "$CONNECTED" ]; then
                if [ "$LAST_ACTIVE" -lt "$2" ]; then
                    xrandr --output "$SOURCE" --right-of "$LAST_ACTIVE_SOURCE" --auto
                elif [ "$LAST_ACTIVE" -gt "$2" ]; then
                    xrandr --output "$SOURCE" --left-of "$LAST_ACTIVE_SOURCE" --auto
                fi
                if [ "$DEFAULT" = 'primary' ]; then
                    xrandr --output "$SOURCE" --primary
                fi
            fi
        fi
        ;;
    on)
        if [ "$2" -le "$MONITORS" ]; then
            eval "ACTIVE=\"\$MONITOR_${2}_ACTIVE\";CONNECTED=\"\$MONITOR_${2}_CONNECTED\";SOURCE=\"\$MONITOR_${2}_SOURCE\";DEFAULT=\"\$MONITOR_${2}_DEFAULT\""
            if [ -z "$ACTIVE" ] && [ -n "$CONNECTED" ]; then
                if [ "$LAST_ACTIVE" -lt "$2" ]; then
                    xrandr --output "$SOURCE" --right-of "$LAST_ACTIVE_SOURCE" --auto
                elif [ "$LAST_ACTIVE" -gt "$2" ]; then
                    xrandr --output "$SOURCE" --left-of "$LAST_ACTIVE_SOURCE" --auto
                fi
                if [ "$DEFAULT" = 'primary' ]; then
                    xrandr --output "$SOURCE" --primary
                fi
            fi
        fi
        ;;
    off|kill)
        if [ "$2" -le "$MONITORS" ]; then
            eval "ACTIVE=\"\$MONITOR_${2}_ACTIVE\";SOURCE=\"\$MONITOR_${2}_SOURCE\";DEFAULT=\"\$MONITOR_${2}_DEFAULT\""
            if [ -n "$ACTIVE" ]; then
                HARD_REDRAW=true
                if [ "$ACTIVE_MONITORS" -le 1 ]; then
                    "$HOME"/.i3/device.sh screen_off
                else
                    xrandr --output "$SOURCE" --off
                    if [ "$PRIMARY" = "$2" ]; then
                        for NO in $(seq $MONITORS); do
                            eval "ACTIVE=\"\$MONITOR_${NO}_ACTIVE\";SOURCE=\"\$MONITOR_${NO}_SOURCE\";DEFAULT=\"\$MONITOR_${NO}_DEFAULT\""
                            if [ -n "$ACTIVE" ] && [ "$NO" != "$2" ]; then
                                xrandr --output "$SOURCE" --primary
                                break
                            fi
                        done
                    fi
                fi
            fi
        fi
        ;;
    orientate|rotate)
        if [ "$2" -le "$MONITORS" ]; then
            eval "ACTIVE=\"\$MONITOR_${2}_ACTIVE\";SOURCE=\"\$MONITOR_${2}_SOURCE\";DEFAULT=\"\$MONITOR_${2}_DEFAULT\""
            if [ -n "$ACTIVE" ]; then # otherwise ignore request
                pack --output "$SOURCE" --rotate "$3"
            fi
        fi
        ;;
    orientate-no-pack|orientate-nopack|orientateno-pack|orientatenopack);&
    rotate-no-pack|rotate-nopack|rotateno-pack|rotatenopack)
        if [ "$2" -le "$MONITORS" ]; then
            eval "ACTIVE=\"\$MONITOR_${2}_ACTIVE\";SOURCE=\"\$MONITOR_${2}_SOURCE\";DEFAULT=\"\$MONITOR_${2}_DEFAULT\""
            if [ -n "$ACTIVE" ]; then # otherwise ignore request
                xrandr --output "$SOURCE" --rotate "$3"
            fi
        fi
        ;;
    mirror|reflect)
        if [ "$2" -le "$MONITORS" ]; then
            eval "ACTIVE=\"\$MONITOR_${2}_ACTIVE\";SOURCE=\"\$MONITOR_${2}_SOURCE\";DEFAULT=\"\$MONITOR_${2}_DEFAULT\""
            if [ -n "$ACTIVE" ]; then # otherwise ignore request
                xrandr --output "$SOURCE" --reflect "$3"
            fi
        fi
        ;;
    primary)
        if [ "$2" -le "$MONITORS" ]; then
            eval "ACTIVE=\"\$MONITOR_${2}_ACTIVE\";SOURCE=\"\$MONITOR_${2}_SOURCE\";DEFAULT=\"\$MONITOR_${2}_DEFAULT\""
            if [ -n "$ACTIVE" ]; then # otherwise ignore request
                xrandr --output "$SOURCE" --primary
            fi
        fi
        ;;
    usage);&
    *)
        {
            echo "Unknown arguments: '$1'${2:+" '$2'"}${3:+" '$3'"}"
            echo "Usage (MHDL? number of monitor as defined in '$HOME/.device_specific/monitor_names.sh'):"
            echo " default"
            echo " all-on"
            echo " pack"
            echo " MHDL1 above MHDL2"
            echo " MHDL1 below MHDL2"
            echo " MHDL1 left-of MHDL2"
            echo " MHDL1 right-of MHDL2"
            echo " MHDL1 same-as MHDL2"
            echo " toggle MHDL1"
            echo " MHDL1 on"
            echo " MHDL1 off"
            echo " MHDL1 primary"
            echo " rotate MHDL1 <normal|left|right|inverted>"
            echo " rotate-no-pack MHDL1 <normal|left|right|inverted>"
            echo " reflect MHDL1 <normal|x|y|xy>"
        } >&2
esac

if [ "${HARD_REDRAW:-false}" = true ] && [ "${XORG_TTY:=1}" -ge 0 ]; then
    xrefresh -black
    sudo chvt 16
    sudo chvt "$XORG_TTY"
fi
