#! /bin/bash
env "$(grep '^LC_CTYPE=' /etc/locale.conf)"\
    st -f "Source Code Pro:pixelsize=14:antialias=true:autohint=false" -c terminal -e "${@}"
