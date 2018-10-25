#! /bin/bash
source "$HOME/.wallpaper_command.sh"
numlockx on
dunst &
compton -CGb &
redshift-gtk -l geoclue2 &
xss-lock -l -- "$HOME/.i3/lock.sh" &
