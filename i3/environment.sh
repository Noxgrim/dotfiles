#! /bin/bash
source "$HOME/.device_specific/wallpaper_command.sh"
numlockx on
pgrep -u "$USER" dunst        || dunst &
pgrep -u "$USER" keynav       || keynav &
pgrep -u "$USER" picom        || picom -CGbi 1 &
pgrep -u "$USER" redshift-gtk || redshift-gtk -l geoclue2 -t 6500K:2500K -b 1.0:0.7 &
pgrep -u "$USER" xss-lock     || xss-lock -l -- "$HOME/.i3/lock.sh" &
pgrep -u "$USER" nm-applet    || nm-applet &
