#! /bin/bash
# Set and modify volume

STEP=2
MAX=100
CURRENT="$(amixer -M -D pulse get Master | grep -oPm1 '\d+(?=%)')"
MUTE="$(amixer -M -D pulse get Master | grep -om1 '\[off\]')"

NEW=
USE_MUTE=

[ "$2" -ge 0 ] && STEP=$2
case "$1" in
    raise)
        NEW=$((CURRENT+STEP))
        ;;
    lower)
        NEW=$((CURRENT-STEP))
        ;;
    mute)
        USE_MUTE=1
        ;;
    set)
        if [ -n "$2" ]; then
            NEW="$2"
        else
            [ -n "$MUTE"  ] && MUTED=' [muted]'
            NEW="$(rofi -dmenu -p 'Set volume: ' -lines 1\
                -mesg "Current volume: $CURRENT%$MUTED, Max: $MAX%"', "[+-]num[%]" or "m[ute]"' < /dev/null)"
        fi

        [ -z "$NEW" ] && exit 0
        if   [[ 'MUTE' =~ ^${NEW^^} ]]; then USE_MUTE=1;
        elif [[ ! "$NEW" =~ ^[+-]?[0-9]+%?$ ]];  then exit 1;
        else 
            [[ "$NEW" =~ %$    ]] && NEW=${NEW:0:-1}
            [[ "$NEW" =~ ^[+-] ]] && NEW=$((CURRENT+NEW))
        fi
        ;;
esac

[ -z "$NEW" ]       && NEW="$CURRENT"
[ "$NEW" -gt $MAX ] && NEW=$MAX
[ "$NEW" -lt 0 ]    && NEW=0

[ $USE_MUTE ] && pactl set-sink-mute   1 toggle
[ "$NEW" ]    && pactl set-sink-volume 1 $NEW%
#[ $USE_MUTE ] && pactl set-sink-mute   0 toggle
#[ "$NEW" ]    && pactl set-sink-volume 0 $NEW%

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
