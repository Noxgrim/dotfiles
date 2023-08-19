#! /bin/bash
if [ "$#" -gt 0 ]; then
    env "$(grep '^LC_CTYPE=' /etc/locale.conf)"\
        alacritty --class terminal,terminal -e "${@}"
else
    env "$(grep '^LC_CTYPE=' /etc/locale.conf)"\
        alacritty --class terminal,terminal
fi
