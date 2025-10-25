#!/usr/bin/env zsh
IFS=$'\n\t'

CONTENT="$(cat)"

export ROFI_WIDTH=1000

case "$1" in
  'Quit window')
    export ROFI_ACCENT=0
    ;;
  *)
    export ROFI_ACCENT=27.8
    ;;
esac

rofi -dmenu -show-icons -markup-rows -i -p "$1" <<< "$CONTENT" 2>/dev/null

