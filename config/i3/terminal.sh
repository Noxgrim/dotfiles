#! /bin/bash
ENV="$(grep '^LC_CTYPE=' /etc/locale.conf)"
if [ "$#" -gt 0 ]; then
    env "$ENV" alacritty msg create-window --class terminal,terminal -e "${@}" || \
    env "$ENV" alacritty                   --class terminal,terminal -e "${@}"
else
    env "$ENV" alacritty msg create-window --class terminal,terminal || \
    env "$ENV" alacritty                   --class terminal,terminal
fi
