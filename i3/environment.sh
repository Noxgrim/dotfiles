#! /bin/bash
source "$HOME/.wallpaper_command.sh"
numlockx on
pgrep dunst        || dunst &
pgrep compton      || compton -CGb &
pgrep redshift-gtk || redshift-gtk -l geoclue2 &
pgrep xss-lock     || xss-lock -l -- "$HOME/.i3/lock.sh" &
