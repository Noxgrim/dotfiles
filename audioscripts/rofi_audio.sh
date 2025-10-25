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

export ROFI_ACCENT='229.8' ROFI_ICONS=false ROFI_WIDTH=980
read -ra INPUT <<< "$(env ROFI_PLACEHOLDER='" Command"' rofi -dmenu -p 'Audio' -lines 1 -filter "$*" < /dev/null 2>/dev/null || echo -- )"
RESULT="$( "$SCRIPT_ROOT/audioscripts/audio.sh" "${ARGS[@]}" "${INPUT[@]}" 2>&1 )"
if [ -n "$RESULT" ]; then
    LINES="$(echo "$RESULT" | wc -l)"
    if [ "$LINES" -gt 38 ]; then
        LINES=38
    fi
    echo "$RESULT" | rofi -i -dmenu -p 'Results' -lines "$LINES"
fi
