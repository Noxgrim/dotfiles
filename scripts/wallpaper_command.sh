#! /bin/bash
if [ -z "${1+O}" ]; then
    # no arg
    if grep -q "00[^']*'"'\|^# locked' "$HOME/.fehbg"; then
        "$HOME/.fehbg"
    else
        find "$HOME/Documents/.wallpaper" \( -type f -o -xtype f \) -print0 | \
            grep -zv '\(^\|/\)00' | sort -zR | xargs -0 feh --bg-scale
    fi
else
    LOCK=false
    # normal arg
    case "$1" in
        !)
            LOCK=true
            ;;
        '?!')
            LOCK=true
            ;&
        '')
            # empty arg
            find "$HOME/Documents/.wallpaper" \( -type f -o -xtype f \) -print0 | \
                grep -zv '\(^\|/\)00' | sort -zR | xargs -0 feh --bg-scale
            ;;
        *!)
            LOCK=true
            set -- "${1%!}"
            ;&
        *)
            find "$HOME/Documents/.wallpaper" \( -type f -o -xtype f \) -print0 | \
                grep -zE "($1)" | sort -zR  | xargs -0 feh --bg-scale
            ;;
    esac
    "$LOCK" && echo '# locked' >> "$HOME/.fehbg"
fi
