#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

DIR="/tmp/$USER"

ICON_SOFT='󰛐'
ICON_HARD='󰈈'


level=
reason=''

if [ -e "$DIR/audio_control/BLOCKING" ]; then
  level="$ICON_SOFT"
  reason='\n'"$ICON_SOFT  "'Playing audio (mpd)'
fi

systemd="$(systemd-inhibit --list --json=pretty |\
  jq -r 'map(select(.mode == "block" and .who != "audio")) | .[] | "\(
    .why) (\(.who), \(.what))"')"
if [ -n "$systemd" ]; then
  level="$ICON_SOFT"
  reason="$reason\\n$ICON_SOFT  $systemd"
fi

if [ -e "$DIR/ssuspend/custom" ]; then
  level="$ICON_HARD"
  reason="$reason\\n$ICON_HARD  "'Explict user idle block'
fi

swayblock="$(swaymsg -t get_tree | jq -r '.. | select(.inhibit_idle? == true) | "\(.app_id // .window_properties.class)"')"
if [ -n "$swayblock" ]; then
  level="$ICON_HARD"
  reason="$reason\\n$ICON_HARD  $swayblock"
fi

if find "$DIR/ssuspend" -mindepth 1 -maxdepth 1 -iname 'browser*' | read -r _; then
  level="$ICON_HARD"
  reason="$reason\\n$ICON_HARD  "'Playing video (browser)'
fi

printf '{"text":"%s","tooltip":"%s"}' "$level" "${reason:2}"

