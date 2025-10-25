#!/usr/bin/env bash
set -euo pipefail -x
IFS=$'\n\t'

case "$1" in
  close)
    if [ "$(dunstctl count displayed)" = 0 ]; then
      i3-msg focus mode_toggle
    else
      dunstctl close
    fi
    ;;
  close-all)
    if [ "$(dunstctl count displayed)" = 0 ]; then
      i3-msg floating toggle
    else
      dunstctl close-all
    fi
    ;;
  context)
    dunstctl context
    ;;
  history)
    dunstctl history-pop
    ;;
esac
