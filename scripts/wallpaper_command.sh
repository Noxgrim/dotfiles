#! /bin/bash
if  [ "$XDG_SESSION_TYPE" = wayland ]; then
    # damn compatibility obsession
    feh2swww() {
        local q
        q="$(swww query)"
        paste <(tr<<<"$q" '\n' '\0'|sed -z 's/[^:]*: \([^:]*\).*/\n\1/')\
              <(tr<"$HOME/.fehbg" '\n' '\0'|sed -zn "/^#/d;s/[^']*'//;s/' '/\\x00/g;s/'\\\\''/'/g;s/'\\s*$//
                        $(sed 'cp;'<<<"$q"|tr -d '\n')" |\
                sed -z 's/\n$//')\
            -z -d: |\
            sed -nz '/^[^\n]/q;s/^\n//;s/^\([^:]*\):/-o\x00\1\x00/p' |\
            xargs -0n3 swww img -t wave
    }
    setwallpaper() {
        readarray -d $'\x00' files
        files=( "${files[@]//"'"/"'\\''"}" )
        files=( "${files[@]/#/"'"}" )
        files=( "${files[@]/%/"'"}" )
        cat > "$HOME/.fehbg" << EOF
#!/bin/sh
feh --no-fehbg --bg-scale ${files[*]}
EOF
        feh2swww
    }
else
    setwallpaper() {
        xargs -0 feh --bg-scale
    }
fi
if [ -z "${1+O}" ]; then
    # no arg
    if grep -q "00[^']*'"'\|^# locked' "$HOME/.fehbg"; then
        if $XORG; then
            "$HOME/.fehbg"
        else
            feh2swww
        fi
    else
        find "$HOME/Documents/.wallpaper" \( -type f -o -xtype f \) -print0 | \
            grep -zv '\(^\|/\)00' | sort -zR | setwallpaper
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
                grep -zv '\(^\|/\)00' | sort -zR | setwallpaper
            ;;
        *!)
            LOCK=true
            set -- "${1%!}"
            ;&
        *)
            find "$HOME/Documents/.wallpaper" \( -type f -o -xtype f \) -print0 | \
                grep -zE "($1)" | sort -zR  | setwallpaper
            ;;
    esac
    "$LOCK" && echo '# locked' >> "$HOME/.fehbg"
fi
