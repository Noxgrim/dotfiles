#! /bin/bash
# A rofi wrapper for 'audio.sh'
ARGS=()
ARGC=0
for ARG in "$@"; do
    if [[ "$ARG" =~ ^- ]]; then
        ARGS[ARGC]="$ARG"
        ((ARGC++))
        shift
    else
        break
    fi
done

read -ra INPUT <<< "$( rofi -theme solarized -dmenu -p 'Audio' -lines 1 -filter "$*" < /dev/null || echo -- )"
RESULT="$( "$SCRIPT_ROOT/audioscripts/audio.sh" "${ARGS[@]}" "${INPUT[@]}" 2>&1 )"
if [ -n "$RESULT" ]; then
    LINES="$(echo "$RESULT" | wc -l)"
    if [ "$LINES" -gt 38 ]; then
        LINES=38
    fi
    echo "$RESULT" | rofi -theme solarized -i -dmenu -p 'Results' -lines "$LINES"
fi
