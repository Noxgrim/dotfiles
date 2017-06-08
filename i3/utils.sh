#! /bin/bash

audio_control() {
    local INPUT=( $( rofi -dmenu -p 'Audio:' -lines 1 < /dev/null || echo -- ) )
    local RESULT
    RESULT="$( "$HOME/.i3/audio.sh" "${INPUT[@]}" 2>&1 )"
    if [ -n "$RESULT" ]; then
        LINES="$(echo "$RESULT" | wc -l)"
        if [ "$LINES" -gt 38 ]; then
            LINES=38
        fi
        echo "$RESULT" | rofi -dmenu -p 'Results:' -lines "$LINES"
    fi
}

workspace() {
    i3-msg move workspace "$(rofi -dmenu -p 'New workspace:' < /dev/null)"
}
