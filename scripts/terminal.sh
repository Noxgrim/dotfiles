#! /bin/bash
ENV="$(grep '^LC_CTYPE=' /etc/locale.conf)"
CLASS='terminal'
if [ "${1-}" = '--fs' ]; then
    CLASS="${CLASS}_fs"
    shift
fi
if [ "$#" -gt 0 ]; then
    env "$ENV" alacritty msg create-window --class "$CLASS,$CLASS" -e "${@}" || \
    env "$ENV" alacritty                   --class "$CLASS,$CLASS" -e "${@}"
else
    env "$ENV" alacritty msg create-window --class "$CLASS,$CLASS" || \
    env "$ENV" alacritty                   --class "$CLASS,$CLASS"
fi
