#! /bin/bash
source "$HOME/.device_specific/wallpaper_command.sh"
numlockx on
pgrep dunst        || dunst &
pgrep picom        || picom -CGbi 1 &
pgrep redshift-gtk || redshift-gtk -l geoclue2 &
pgrep xss-lock     || xss-lock -l -- "$HOME/.i3/lock.sh" &
pgrep nm-applet    || nm-applet &
