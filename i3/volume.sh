#! /bin/bash
# Set and modify volume
source $HOME/.device_specific/default_sink.sh
SINK_DATA="$(pactl list sinks | grep "\\b$SINK\\b" -m1 -A8)"
STEP=2
MAX=100
CURRENT="$(grep Volume <<< "$SINK_DATA"| grep -m1 -oP '\d+(?=%)' | head -n 1)"
MUTE="$(grep Mute <<< "$SINK_DATA" | grep -om1 'yes')"

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
            echo " <raise|raise!|lower> {num}"
            echo " <set|set!> <mute|[[+-]num]>"
            echo " mute"
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
