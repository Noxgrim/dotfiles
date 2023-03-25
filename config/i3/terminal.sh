#! /bin/bash
env "$(grep '^LC_CTYPE=' /etc/locale.conf)"\
    alacritty --class terminal,terminal -e "${@}"
