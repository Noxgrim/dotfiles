#! /bin/bash

audio_control() {
    RESULT="$($HOME/.i3/audio.sh $( ! rofi -dmenu -p 'Audio:' -lines 1 && echo -- ) 2>&1 )"
    if [ -n "$RESULT" ]; then
        LINES="$(echo "$RESULT" | wc -l)"
        if [ "$LINES" -gt 47 ]; then
            echo "$RESULT" | rofi -dmenu -p 'Results:' -lines 38
        else
            rofi -e "$RESULT"
        fi
    fi
}

workspace() {
    i3-msg move workspace "$(rofi -dmenu -p 'New workspace:' < /dev/null)"
}
