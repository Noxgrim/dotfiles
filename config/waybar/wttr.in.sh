##!/usr/bin/env bash
# Based on: https://github.com/Alexays/Waybar/wiki/Module:-Custom:-Examples#weather
# shellcheck disable=SC1091
source "$SCRIPT_ROOT/data/shared/local_env.sh"


for _ in {1..5}; do
    text="$(curl -s "https://wttr.in/$GEO_LON,$GEO_LAT?format=1")"
    if [ "$?" == 0 ]; then
        text="$(sed 's/\s+/ /g' <<< "$text")"
        tooltip="$(curl -s "https://wttr.in/$GEO_LON,$GEO_LAT?Tqp0")"
        if [ "$?" == 0 ] && [ -n "$tooltip" ]; then
            tooltip=$(head -n-1 <<< "$tooltip" | tail -n+4 | sed 's/^     //' | terminal-to-html)
            dt="$(head -n1 <<< "$tooltip" | grep -o '^\s*')$(date '+(%R)')"
            jq -nc \
              --arg txt "$text" \
              --arg tlt "<tt>$tooltip"$'\n'"$dt</tt>" \
              '{text:$txt,tooltip:$tlt}'
            exit
        fi
    fi
    sleep 2
done
echo '{"text":" \uf057"}'
