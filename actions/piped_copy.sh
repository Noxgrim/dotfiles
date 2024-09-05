#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

PIPED_URL='https://www.youtube.com'

get_piped() {
    xclip -sel c -o | case "$(xclip -sel c -o)" in
        'https://www.youtube.com/watch?v='*)
            sed 's,^https://www.youtube.com/watch?v=,,'
            ;;
        'https://youtu.be/'*)
            sed 's,^https://youtu.be/,,'
            ;;
        'https://piped.'*'/watch?v='*)
            sed 's,^https://piped.[^/]*/watch?v=,,'
            ;;
        '{'*) # aussume copied debug info from YouTube, needed for some ads
            jq '.addebug_videoId, .debug_videoId' -r | sed  '/^\(null\|\)$/d' | head -n1
            ;;
        *)
            echo 'Unknown format in clipboard…' >&2 && return 1
            ;;
    esac | sed 's,^,'"$PIPED_URL"'/watch?v=,'
}
case "${1-link}" in
    link)
        get_piped | xclip -sel c -r
        ;;
    open)
        get_piped | xargs -0 xdg-open &>/dev/null & disown
        ;;
esac


