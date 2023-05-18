#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'


setxkbmap -option shift:both_capslock
setxkbmap -option caps:ctrl_modifier
setxkbmap -option compose:rctrl-altgr
setxkbmap -option compose:lwin-altgr
setxkbmap -option compose:prsc
pgrep -u "$USER" xcape || xcape -e 'Caps_Lock=Escape;Control_R=Menu' -t 210
