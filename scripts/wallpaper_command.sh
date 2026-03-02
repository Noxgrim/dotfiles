#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
export ROFI_ICONS=true ROFI_ACCENT=249.2

DIR="$HOME/Documents/.wallpaper"
ASSETS="$SCRIPT_ROOT/assets/wallpaper"
FEH="$HOME/.fehbg"
if  [ "$XDG_SESSION_TYPE" = wayland ]; then
    # damn compatibility obsession
    feh2swww() {
        local q
        q="$(swww query | sort -t: -k2,2)"
        paste <(tr<<<"$q" '\n' '\0'|sed -z 's/[^:]*: \([^:]*\).*/\n\1/')\
              <(tr<"$FEH" '\n' '\0'|sed -zn "/^#/d;s/[^']*'//;s/' '/\\x00/g;s/'\\\\''/'/g;s/'\\s*$//
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
        local IFS=' '
        cat > "$FEH" << EOF
#!/bin/sh
feh --no-fehbg --bg-scale ${files[*]}
EOF
        feh2swww
    }
    monitornamewidth() {
        # @s for length fadding
        swww query | sed 's/^: .\([^:]*\).*/@@\1/;s/./x/g' | sort | tail -n1 | wc -m
    }
    fetchmonitorstate() {
        awk 'BEGIN {FS=OFS="\t"} FNR==NR{a[$1]=$3;b[$1]=$2;next} {print $1,a[$2]==""?"(External image)":a[$2],b[$2]==""?$2:b[$2]}'\
            <(paste <(sed '1d;s,\([^,]*\).*,'"$DIR/"'\1,' "$DIR/.metadata"|xargs readlink -f) \
                    <(sed '1d;s/\\n/ /g;s|\(^[^,]*\),\([^,]*,[^a-zA-Z0-9]\)*\([^,]*\),.*|'"$DIR/"'\1\t\2\3|' "$DIR/.metadata")) \
            <(swww query | sed 's/^: \([^:]*\):[^/]*\(.*\)/\1\t\2/' | \
              sort -t$'\t' -k1,1)
    }
    insertwallpaper() {
        swww img -t wave -o "$1" "$3"
        local old="${2//"'"/"'\\''"}" new="${3//"'"/"'\\''"}"
        old="${old/#/"'"}" new="${new/#/"'"}"
        old="${old/%/"'"}" new="${new/%/"'"}"
        sed "s/ $(sed 's/./[&]/g' <<< "$old")/ $(sed 's/[&/\]/\\&/g' <<< "$new")/g" \
            -i "$FEH"
    }
else
    setwallpaper() {
        xargs -0 feh --bg-scale
    }
    monitornamewidth() {
        # @s for length fadding
        xrandr --listactivemonitors | sed '1d;s/^.*  ./@@/;s/./x/g' | sort | tail -n1 | wc -m
    }
    fetchmonitorstate() {
        local q
        q="$(xrandr --listactivemonitors | sed '1d;s/^.*  //')"
        awk 'BEGIN {FS=OFS="\t"} FNR==NR{a[$1]=$2;next} {print $1,a[$2],$2}'\
            <(sed '1d;s/\\n/ /g;s|\(^[^,]*\),\([^,]*,[^a-zA-Z0-9]\)*\([^,]*\),.*|'"$DIR/"'\1\t\2\3|' "$DIR/.metadata") \
            <(paste - <<<"$q" <(tr<"$FEH" '\n' '\0'|
                  sed -zn "/^#/d;s/[^']*'//;s/' '/\\x00/g;s/'\\\\''/'/g;s/'\\s*$//
                                $(sed 'cp;'<<<"$q"|tr -d '\n')" | sed -z 's/\n$//' \
                                | tr '\0' '\n' | head -n "$(wc -l <<< "$q")") \
                                | sort -t$'\t' -k1,1)
    }
    insertwallpaper() {
        local old="${2//"'"/"'\\''"}" new="${3//"'"/"'\\''"}"
        old="${old/#/"'"}" new="${new/#/"'"}"
        old="${old/%/"'"}" new="${new/%/"'"}"
        sed "s/ $(sed 's/./[&]/g' <<< "$old")/ $(sed 's/[&/\]/\\&/g' <<< "$new")/g" \
            -i "$FEH"
        "$FEH"
    }
fi
if [ -z "${1+O}" ]; then
    # no arg
    if grep -q "00[^']*'"'\|^# pinned' "$FEH"; then
        if $XORG; then
            "$FEH"
        else
            feh2swww
        fi
    else
        find "$DIR" \( -type f -o -xtype f \) -print0 | \
            grep -zv '\(^\|/\)\(\.\|00\)[^/]*$' | sort -zR | setwallpaper
    fi
    return
fi
case "$1" in
    --select|-s)
        while :; do
            if grep -q '^# pinned' "$FEH"; then
                PINKEY=unpin PINPHRASE='Unpin wallpapers' PINICON="$ASSETS/icon-unpin"
            else
                PINKEY=pin   PINPHRASE='Pin wallpapers'   PINICON="$ASSETS/icon-pin"
            fi
            # main menu
            KEY="$({
                fetchmonitorstate | sed 's/^[^\t]*\t/&&/;s,\t\(/.*$\),\t\1\x00icon\x1f\1,'
                cat << EOF | tr '\001' '\0'
@group		Multi-select a pool	$(printf '\x01icon\x1f%s' "$ASSETS/icon-group")
@$PINKEY		$PINPHRASE	$(printf '\x01icon\x1f%s' "$PINICON")
EOF
                } | env ROFI_ICON_SIZE=2em rofi -dmenu -display-column-separator $'\t' -display-columns 2,3 \
                    -no-custom -p 'Wallpaper' \
                    -theme-str "element-text {tab-stops: [$(monitornamewidth)ch];}" | cut -f1,3-4 || echo @exit)"
            case "$KEY" in
                @exit)
                    exit 0
                    ;;
                @pin*)
                    grep -q '^# pinned' "$FEH" || echo '# pinned' >> "$FEH"
                    ;;
                @unpin*)
                    sed '/^# pinned/d' -i "$FEH"
                    ;;
                @group*)
                    sed '1d;s,^,'"$DIR/"',;s,\\n,\x1c,g;s/\([^,]*\).*/&\x00icon\x1f\1/;
                         s|\(^[^,]*\),\([^,]*,[^a-zA-Z0-9]\)*\([^,]*\)|\1,\2\3</span>|' \
                        "$DIR/.metadata" | tr '\034\n' '\n\034' | \
                        env ROFI_PLACEHOLDER="\" Multi-Select\"" \
                        rofi -dmenu -show-icons -config config-pictures -scroll-method 0 \
                        -display-columns 2 -display-column-separator ',(?=\w)' -sep $'\034' -i \
                        -no-custom -p 'Wallpaper' -multi-select \
                        -ballot-unselected-str '<span>' -ballot-selected-str '<span alpha="20%">' \
                        -markup-rows | cut -d, -f1 | tr '\n' '\0' | sort -zR | setwallpaper || true
                    ;;
                *)
                    case "$KEY" in
                        *$'\t(External image)\t'*)
                            SELECTION="${KEY/$'\t('/ (currently “}"
                            SELECTION="${SELECTION/$')\t'/” (}))"
                            ;;
                        *)
                            SELECTION="${KEY/$'\t'/ (currently “}"
                            SELECTION="${SELECTION%$'\t'*}”)"
                            ;;
                    esac
                    SELECTION="$({
                        sed '1d;s,^,'"$DIR/"',;s,\\n,\x1c,g;s/\([^,]*\).*/&\x00icon\x1f\1/' \
                        "$DIR/.metadata" | tr '\034\n' '\n\034';
                        cat << EOF | tr '\001\n' '\0\034'
@random,<i>Random</i>,shuffle$(printf '\x01icon\x1f%s' "$ASSETS/icon-random")
@browse,<i>Browse</i>,select external$(printf '\x01icon\x1f%s' "$ASSETS/icon-browse")
EOF
                        } | env ROFI_PLACEHOLDER="\" $SELECTION\"" \
                        rofi -dmenu -show-icons -config config-pictures -scroll-method 0 \
                        -display-columns 2 -display-column-separator ',(?=\w|<)' -sep $'\034' -i \
                        -no-custom -p 'Wallpaper' -markup-rows | head -n1 | cut -d, -f1 || echo '')"
                    case "$SELECTION" in
                        @random)
                            # do not select a 00 wallpaper or one of the currently actives
                            SELECTION="$(fetchmonitorstate | cut -d$'\t' -f1 |\
                                sort - <(cut -d, -f1 "$DIR/.metadata")|uniq -u|grep -v '^\(/.*|00.*\)'|\
                                shuf -n1|sed 's,^,'"$DIR/,")"
                            ;;
                        @browse)
                            while SELECTION="$(ROFI_ICON_SIZE=2em rofi -modes filebrowser -show filebrowser\
                                -filebrowser-cancel-returns-1 true -filebrowser-command printf)"; do
                                SELECTION="$(readlink -f "$SELECTION")" || continue
                                case "$(file --mime-type -b "$SELECTION")" in
                                    image/*)
                                        break
                                        ;;
                                    *)
                                        echo >&2 'Unsupported file type. Select again.'
                                esac
                            done
                    esac
                    if [ -n "$SELECTION" ]; then
                        insertwallpaper "${KEY%%$'\t'*}" "${KEY##*$'\t'}" "$SELECTION"
                    fi
                    ;;
            esac
        done
        ;;
    *)
    PIN=false
    # normal arg
    case "$1" in
        !)
            PIN=true
            ;;
        '?!')
            PIN=true
            ;&
        '')
            # empty arg
            find "$DIR" \( -type f -o -xtype f \) -print0 | \
                grep -zv '\(^\|/\)\(\.\|00\)[^/]*$' | sort -zR | setwallpaper
            ;;
        *!)
            PIN=true
            set -- "${1%!}"
            ;&
        *)
            find "$DIR" \( -type f -o -xtype f \) -print0 | \
                grep -zv '\(^\|/\)\.[^/]*$' | grep -zE "($1)" | sort -zR  | setwallpaper
            ;;
    esac
    "$PIN" && echo '# pinned' >> "$FEH"
esac
