#!/bin/bash
set -eu -o pipefail
exec 4>/var/tmp/monitor_script.lock || exit 1
flock 4 || exit 1

# shellcheck source=/home/noxgrim/.device_specific/monitor_names.sh
source "$HOME/.device_specific/monitor_names.sh"
CURRENT="/tmp/$USER/sway/output.sway"
SWAYCFG="$SCRIPT_ROOT/config/sway/output.sway"

TARGET_SOURCE="$(swaymsg -t get_workspaces | jq 'map(select(.focused)) | .[0].output' -r)"

CONNECTED=( '' "${SOURCES[@]/*/false}" )
ACTIVE=( '' "${SOURCES[@]/*/false}" )
POWER=( '' "${SOURCES[@]/*/false}" )
NUM_ACTIVE=0
LASTOFF=-1
PACK=true
FOCUSED=-1
FOCUSEDWS=''
MODE=()
TRANSFORM=()
X=()
Y=()
W=()
H=()

init() {
    local OUT NAME ID IDX ISACTIVE ISPOWER ISFOCUSED FILE ISTRANSFORM ISMODE ISX ISY ISW ISH ISFOCUSEDWS
    # parse current state
    while read -r OUT; do
        eval "$(jq -r '"NAME=\"\(.name)\"\n
        ID=\"\(.make) \(.model) \(.serial)\"\n
        ISACTIVE=\"\(.active)\"\n
        ISPOWER=\"\(.power//false)\"\n
        ISX=\"\(.rect?.x?)\"\n
        ISY=\"\(.rect?.y?)\"\n
        ISW=\"\(.rect?.width?)\"\n
        ISH=\"\(.rect?.height?)\"\n
        ISMODE=\"\(.current_mode?.width?)x\(.current_mode?.height?)\"\n
        ISTRANSFORM=\"\(.transform//"normal")\"\n
        ISFOCUSED=\"\(.focused//false)\"\n
        ISFOCUSEDWS=\"\(.current_workspace//"")\"\n
        "' <<< "$OUT")"

        IDX="${SOURCES["$NAME"]}"
        CONNECTED["$IDX"]=true
        ACTIVE["$IDX"]="$ISACTIVE"
        POWER["$IDX"]="$ISPOWER"
        if $ISFOCUSED; then
            FOCUSED="$IDX"
            FOCUSEDWS="$ISFOCUSEDWS"
        fi
        if $ISACTIVE; then
            ((++NUM_ACTIVE))
        else
            if [ -e "$CURRENT" ] && grep -qE "($NAME|$ID)" "$CURRENT"; then
                FILE="$CURRENT"
            else
                FILE="$SWAYCFG"
            fi
            eval "$(sed -n '
                '"/$ID"'\s*{/,/}/{
                    /mode/s/[^0-9]*\([0-9]*\)x\([0-9]*\).*/ISMODE="\1x\2"\nISW="\1"\nISH="\2"/p
                    /position/s/[^0-9]*\([0-9]*\)\s*\([0-9]*\).*/ISX="\1"\nISY="\2"/p
                    /transform/s/\s*[^ ]*\s*\([^ ]*\).*/ISTRANSFORM="\1"/p
                    /}/q
                }
                '"/$NAME"'\s*{/,/}/{
                    /mode/s/[^0-9]*\([0-9]*\)x\([0-9]*\).*/ISMODE="\1x\2"\nISW="\1"\nISH="\2"/p
                    /mode/s/[^0-9]*\([0-9]*\)x\([0-9]*\).*/ISW="\1"\nISH="\2"/p
                    /position/s/[^0-9]*\([0-9]*\)\s*\([0-9]*\).*/ISX="\1"\nISY="\2"/p
                    /transform/s/\s*[^ ]*\s*\([^ ]*\).*/ISTRANSFORM="\1"/p
                }' "$FILE")"
            if [ -z "${ISMODE-}" ]; then
                eval "$(jq -r '
                ISMODE=\"\(.modes[0].width)x\(.modes[0].height)\"\n
                ISW=\"\(.modes[0].width)\"\n
                ISH=\"\(.modes[0].height)\"\n
                "' <<< "$OUT")"
            fi
            case "${ISTRANSFORM-normal}" in
                *90|*270)
                    Z="$ISW"
                    ISW="$ISH"
                    ISH="$Z"
                    ;;
            esac
        fi
        MODE["$IDX"]="$ISMODE"
        TRANSFORM["$IDX"]="$ISTRANSFORM"
        X["$IDX"]="$ISX" Y["$IDX"]="$ISY"
        W["$IDX"]="$ISW" H["$IDX"]="$ISH"
    done < <(swaymsg -t get_outputs | jq -c '.[]')
}

init_defaults() {
    local NXTX=0 NXTY=0 OUT NAME ID IDX ISACTIVE ISPOWER ISTRANSFORM ISMODE ISX ISY ISW ISH
    while read -r OUT; do
        eval "$(jq -r '"NAME=\"\(.name)\"\n
        ID=\"\(.make) \(.model) \(.serial)\"\n
        "' <<< "$OUT")"

        IDX="${SOURCES["$NAME"]}"
        ISACTIVE=true
        ISPOWER=true
        ISTRANSFORM=normal
        ISX="$NXTX"
        ISY="$NXTY"
        ISMODE=''
        eval "$(sed -n '
            '"/$ID"'\s*{/,/}/{
                /mode/s/[^0-9]*\([0-9]*\)x\([0-9]*\).*/ISMODE="\1x\2"\nISW="\1"\nISH="\2"/p
                /position/s/[^0-9]*\([0-9]*\)\s*\([0-9]*\).*/ISX="\1"\nISY="\2"/p
                /transform/s/\s*[^ ]*\s*\([^ ]*\).*/ISTRANSFORM="\1"/p
                /power/{s/.*on.*/ISPOWER="true"/p;s/.*off.*/ISPOWER="false"/p;}
                /enable/s/ISACTIVE="true"/p
                /disable/s/ISACTIVE="false"/p
                /}/q
            }
            '"/$NAME"'\s*{/,/}/{
                /mode/s/[^0-9]*\([0-9]*\)x\([0-9]*\).*/ISMODE="\1x\2"\nISW="\1"\nISH="\2"/p
                /mode/s/[^0-9]*\([0-9]*\)x\([0-9]*\).*/ISW="\1"\nISH="\2"/p
                /position/s/[^0-9]*\([0-9]*\)\s*\([0-9]*\).*/ISX="\1"\nISY="\2"/p
                /transform/s/\s*[^ ]*\s*\([^ ]*\).*/ISTRANSFORM="\1"/p
                /power/{s/.*on.*/ISPOWER="true"/p;s/.*off.*/ISPOWER="false"/p;}
                /enable/s/ISACTIVE="true"/p
                /disable/s/ISACTIVE="false"/p
            }' "$SWAYCFG")"
        if [ -z "${ISMODE-}" ]; then
            eval "$(jq -r '
            ISMODE=\"\(.modes[0].width)x\(.modes[0].height)\"\n
            ISW=\"\(.modes[0].width)\"\n
            ISH=\"\(.modes[0].height)\"\n
            "' <<< "$OUT")"
        fi
        case "${ISTRANSFORM-normal}" in
            *90|*270)
                Z="$ISW"
                ISW="$ISH"
                ISH="$Z"
                ;;
        esac
        ACTIVE["$IDX"]="$ISACTIVE"
        POWER["$IDX"]="$ISPOWER"
        MODE["$IDX"]="$ISMODE"
        TRANSFORM["$IDX"]="$ISTRANSFORM"
        X["$IDX"]="$ISX" Y["$IDX"]="$ISY"
        W["$IDX"]="$ISW" H["$IDX"]="$ISH"
        NXTX=$((ISX+ISW))
        NXTY="$ISY"
    done < <(swaymsg -t get_outputs | jq -c '.[]')
}

pack() {
    local DATA=''
    for IDX in "${SOURCES[@]}"; do
        if "${ACTIVE["$IDX"]}"; then
            DATA="
            \"$IDX\": {
                \"x\": ${X["$IDX"]},
                \"y\": ${Y["$IDX"]},
                \"w\": ${W["$IDX"]},
                \"h\": ${H["$IDX"]}
                }
            ,$DATA"
        fi
    done
    DATA="{${DATA%,}}"
    eval "$(python3 "$TDIR/output_layout.pack.py" "$DATA")"
}


init
set -- "${@/./"$FOCUSED"}"


while [ "$#" != 0 ]; do
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        set -- "${2-}" "$1" "${@:3}"
    fi
    case "${1//-/}" in
        primary) # compatibility
            shift 1
            ;;
        default)
            init_defaults
            ;;
        nopack)
            PACK=false
            ;;
        allon)
            readarray ACTIVE < <(echo "${SOURCES[@]/*/true}")
            ;;
        above)
            X["$2"]=${X[$3]}
            Y["$2"]=$((${Y[$3]}-${H[$2]}))
            shift 2
            ;;
        below)
            X["$2"]=${X[$3]}
            Y["$2"]=$((${Y[$3]}+${H[$3]}))
            shift 2
            ;;
        leftof)
            X["$2"]=$((${X[$3]}-${W[$2]}))
            Y["$2"]=${Y[$3]}
            shift 2
            ;;
        rightof)
            X["$2"]=$((${X[$3]}+${W[$3]}))
            Y["$2"]=${Y[$3]}
            shift 2
            ;;
        sameas)
            X["$2"]=${X[$3]}
            Y["$2"]=${Y[$3]}
            shift 2
            ;;
        toggle)
            if "${ACTIVE["$2"]}"; then
                ACTIVE["$2"]=false
                POWER["$2"]=false
                LASTOFF="$2"
                : $((--NUM_ACTIVE))
            else
                ACTIVE["$2"]=true
                POWER["$2"]=true
                ((++NUM_ACTIVE))
            fi
            shift 1
            ;;
        on)
            ACTIVE["$2"]=true
            POWER["$2"]=true
            ((++NUM_ACTIVE))
            shift 1
            ;;
        off|kill)
            ACTIVE["$2"]=false
            POWER["$2"]=false
            LASTOFF="$2"
            : $((--NUM_ACTIVE))
            shift 1
            ;;
        orientateonly|rotateonly)
            TARGETS=("$2")
            ;&
        orientate|rotate)
            # rotate all mirroring screens to avoid packaing weirdness
            if [ -z "${TARGETS:+z}" ]; then
                TARGETS=()
                for N in "${SOURCES[@]}"; do
                    "${ACTIVE[$N]}"  && [ "${X[$N]}" == "${X[$2]}" ] && [ "${Y[$N]}" == "${Y[$2]}" ] && \
                        TARGETS+=("$N")
                done
            fi
            for N in "${TARGETS[@]}"; do
                case "${TRANSFORM["$N"]}" in
                    flipped*) PFX='flipped';;
                    *) PFX=''
                esac
                case "$3" in
                    normal)   TRANSFORM["$N"]="${PFX:-normal}";;
                    right)    TRANSFORM["$N"]="${PFX:+$PFX-}90";;
                    left)     TRANSFORM["$N"]="${PFX:+$PFX-}270";;
                    inverted) TRANSFORM["$N"]="${PFX:+$PFX-}180";;
                esac
                IFS='x@' read -r MW MH _ <<< "${MODE["$N"]}"
                case "$3" in
                    right|left) W["$N"]="$MH" H["$N"]="$MW";;
                    *)          W["$N"]="$MW" H["$N"]="$MH";;
                esac
            done
            shift 2
            ;;
        mirror|reflect)
            # emulate xrandr flipping, not that I ever used it…
            SUF="${TRANSFORM["$2"]#flipped}"
            SUF="${SUF#-}"
            SUF="${SUF%normal}"
            case "$3" in
                normal) TRANSFORM["$2"]="${SUF:-normal}";;
                y)
                    SUF=${SUF:-0}
                    SUF=$(((SUF+180)%360))
                    [ "$SUF" == 0 ] && SUF=''
                    ;&
                x)  case "${TRANSFORM["$2"]}" in
                        flipped*) TRANSFORM["$2"]="${SUF:-normal}";;
                        *)        TRANSFORM["$2"]="flipped${SUF:+$SUF-}";;
                    esac;;
                xy)
                    SUF=${SUF:-0}
                    SUF=$(((SUF+180)%360))
                    [ "$SUF" == 0 ] && SUF=''
                    case "${TRANSFORM["$2"]}" in
                        flipped*) TRANSFORM["$2"]="flipped${SUF:+$SUF-}";;
                        *)        TRANSFORM["$2"]="${SUF:-normal}";;
                    esac;;
            esac
            shift 2
            ;;
        usage)
            {
                echo "Usage (MHDL? number of monitor as defined in '$HOME/.device_specific/monitor_names.sh'):"
                echo " default"
                echo " all-on"
                echo " MHDL1 above MHDL2"
                echo " MHDL1 below MHDL2"
                echo " MHDL1 left-of MHDL2"
                echo " MHDL1 right-of MHDL2"
                echo " MHDL1 same-as MHDL2"
                echo " toggle MHDL1"
                echo " MHDL1 on"
                echo " MHDL1 off"
                echo " rotate MHDL1 <normal|left|right|inverted>"
                echo " rotate-only MHDL1 <normal|left|right|inverted>"
                echo " no-pack"
                echo " reflect MHDL1 <normal|x|y|xy>"
            } >&2
            exit 0
        ;;
        *)
            break 2
    esac
    shift 1
done

if [ $NUM_ACTIVE == 0 ]; then
    ACTIVE["$LASTOFF"]=true
    ((NUM_ACTIVE++))
    POWER["$LASTOFF"]=false
fi

$PACK && pack

{
    echo 'output {'
    for OUT in "${!SOURCES[@]}"; do
        IDX=${SOURCES[$OUT]}
        echo "  $OUT {"
        if "${CONNECTED["$IDX"]}"; then
            [ -n "${MODE["$IDX"]-}" ] && printf '    mode %s\n' "${MODE["$IDX"]}"
            printf '    position %s %s\n' "${X["$IDX"]-0}" "${Y["$IDX"]-0}"
            printf '    transform %s\n' "${TRANSFORM["$IDX"]-normal}"

        fi
        printf '    power '
        ${POWER["$IDX"]} && echo on || echo off
        printf '    '
        ${ACTIVE["$IDX"]} && echo enable || echo disable
        echo '  }'
    done
    echo '}'
    echo '# vim: ft=swayconfig'
} > "$CURRENT"

mv "$SWAYCFG" "$SWAYCFG.default"
ln -sf "$CURRENT" "$SWAYCFG"
swaymsg reload
mv "$SWAYCFG.default" "$SWAYCFG"

[ -n "$FOCUSEDWS" ] && swaymsg workspace "$FOCUSEDWS"

CONNECTED_MONTORS_FILE="/tmp/$USER/connected_montors"
CONNECTED_LIST="$(for K in "${!SOURCES[@]}"; do "${CONNECTED["${SOURCES["$K"]}"]}" && echo "$K"; done)"
touch "$CONNECTED_MONTORS_FILE"
if ! sort -u <<< "$CONNECTED_LIST" | diff <(sort -u "$CONNECTED_MONTORS_FILE") -; then
    echo 'brightness reload' > "/tmp/$USER/service"
    sleep .1
    while [ -f "/tmp/$USER/service.working" ]; do
        sleep 1
    done
fi
ACTIVEN=()
for N in "${SOURCES[@]}"; do "${ACTIVE["$N"]}" && ACTIVEN["$N"]="$N"; done
device brightness select "${ACTIVEN[@]}"
echo "$CONNECTED_LIST" > "$CONNECTED_MONTORS_FILE"
