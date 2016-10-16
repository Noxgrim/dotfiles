#! /bin/bash

audio_control() {
    RESULT="$($HOME/.i3/audio.sh $( rofi -dmenu -p 'Audio:' < /dev/null ))"
    if [ -n "$RESULT" ]; then
        rofi -e "$RESULT"
    fi
}

workspace() {
    i3-msg move workspace "$(rofi -dmenu -p 'New workspace:' < /dev/null)"
}
