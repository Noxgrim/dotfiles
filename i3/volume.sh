#! /bin/bash
# Set and modify volume

# This file must contain a array `SINKS` with the name of the sinks to consider
# in order of priority.
# shellcheck source=/home/noxgrim/.device_specific/default_sink.sh
source "$HOME/.device_specific/default_sink.sh"

STEP=2
MAX=100

if [ "${1:?"First should be non-empty!"}" = 'select' ]; then
    if [ "$2" == 'unset' ] && [ "$3" == 'active' ]; then
        [ -f '/tmp/noxgrim/volume/active' ] && rm '/tmp/noxgrim/volume/active'
        exit
    fi

    readarray -t SINKS < <(pactl list sinks | grep 'device.description\|^\s*Name' | sed 's/^\s*Name: //;s/.*"\(.*\)".*$/\1/')
    SINK="$(for ((I=1; I < ${#SINKS[@]}; I+=2)); do printf '%s\n' "${SINKS[$I]}"; done | rofi -dmenu -no-custom -i -p\
            "Select $([ "$2" == 'set' ] && [ "$3" == 'active' ] && echo 'active ' || echo '')sink" -theme solarized)"
    [ -z "$SINK" ] && exit
    for ((I=0; I < ${#SINKS[@]}; I+=2)); do
        if [ "${SINKS[$I+1]}" = "$SINK" ]; then
            SINKS=( "${SINKS[$I]}" )
            break
        fi
    done

    if [ "$2" == 'set' ] && [ "$3" == 'active' ]; then
        [ -d '/tmp/noxgrim/volume/' ] || mkdir -p '/tmp/noxgrim/volume/'
        printf '%s\n' "${SINKS[0]}" > '/tmp/noxgrim/volume/active'
        exit
    fi
    shift 1
elif [ -f '/tmp/noxgrim/volume/active' ]; then
    SINKS=( "$(cat '/tmp/noxgrim/volume/active')" )
fi

for SINK in "${SINKS[@]}"; do
    SINK_DATA="$(pactl list sinks | sed -n '/^\s*Name: '"$SINK"'/,/^\s*$/p')"
    if [ -n "$SINK_DATA" ]; then
        CURRENT="$(grep Volume <<< "$SINK_DATA"| grep -m1 -oP '\d+(?=%)' | head -n 1)"
        MUTE="$(grep Mute <<< "$SINK_DATA" | grep -om1 'yes')"
        break
    fi
done

NEW=
USE_MUTE=

[ "${2:-}" = '_' ] && set -- "$1"

[ -n "$2"  ] && [ "$2" != '_' ] && [ "$2" -ge 0 ] && STEP=$2
case "$1" in
    raise!)
        OVERDRIVE=true
        ;&
    raise)
        NEW=$((CURRENT+STEP))
        ;;
    lower)
        NEW=$((CURRENT-STEP))
        ;;
    mute)
        USE_MUTE=1
        ;;
    set!)
        OVERDRIVE=true
        ;&
    set)
        if [ -n "$2" ]; then
            NEW="$2"
        else
            [ -n "$MUTE"  ] && MUTED=' [muted]'
            NEW="$(rofi -dmenu -p 'Set volume' -theme solarized -lines 1\
                -mesg "Current volume: $CURRENT%$MUTED, Max: $MAX%"', "[+-]num[%]" or "m[ute]"'"$([ "${OVERDRIVE:-false}" = true ] && echo ' {overdrive mode}')" < /dev/null)"
        fi

        [ -z "$NEW" ] && exit 0
        if   [[ 'MUTE' =~ ^${NEW^^} ]]; then USE_MUTE=1;
        elif [[ ! "$NEW" =~ ^[+-]?[0-9]+%?$ ]];  then exit 1;
        else
            [[ "$NEW" =~ %$    ]] && NEW=${NEW:0:-1}
            [[ "$NEW" =~ ^[+-] ]] && NEW=$((CURRENT+NEW))
        fi
        ;;
    usage)
        ;&
    *)
        {
            echo "Unknown command: ${1:-}"
            echo "Usage:"
            echo " <select|> <raise|raise!|lower> {num}"
            echo " <select|> <set|set!> <mute|[[+-]num]>"
            echo " <select|> mute"
            echo " select <set|unset> active"
        } >&2
        exit 1
esac

[ -z "$NEW" ]       && NEW="$CURRENT"
[ "${OVERDRIVE:-false}" = false ] && [ "$NEW" -gt $MAX ] && NEW=$MAX
[ "$NEW" -lt 0 ]    && NEW=0

[ "$NEW" ]      && pactl set-sink-volume "$SINK" $NEW%
[ "$USE_MUTE" ] && pactl set-sink-mute "$SINK" toggle

if [ $USE_MUTE ]; then
    [ -z "$MUTE" ] && MUTED=''         || MUTED=' [muted]'
else
    [ -n "$MUTE" ] && MUTED=' [muted]' || MUTED=''
fi

if [ -n "$NEW" ] && [ "$NEW" != "$CURRENT" ]; then INS='%n%'
elif [ -n "$MUTED" ]; then MUTED='unmuted'
else MUTED='muted'; fi

if [ -n "$INS" ] || [ $USE_MUTE ]; then
    if [ -n "$INS" ]; then
        notify-send -a "noxgrim:volume" -u low -h "int:value:$NEW" 'Volume ' "%$MUTED"
    else
        notify-send -a "noxgrim:volume:mute_action" -u low 'Volume ' "$MUTED"
    fi
fi
