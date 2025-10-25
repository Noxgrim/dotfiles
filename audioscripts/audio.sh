#! /bin/bash

MPC='mpc -q'
BROWSER=( rofi -dmenu -i -multi-select -p 'Browse')
AU_DIR="/tmp/$USER/audio_control"
PROVIDER='mpd'
MPD_CONF="$HOME/.config/mpd/mpd.conf"
export MPD_HOST
MUSIC_DIR="$(grep 'music_directory' "$MPD_CONF" | grep -oP '(?<=").*?(?=")' |\
    sed -r "s/~/$( sed 's/[&/\]/\\&/g' <<<"$HOME"  )/" )"
ICON_RES='80:80' #Only affects newly created icons
#PLAYLIST_FORMAT='%position%. %artist% • %title%'
PLAYLIST_FORMAT='%position%. [[[%title%][ • %artist%][ • %album%]]|[%name%]|[%file%]]|[?]'
PLAYLIST_SEARCH_FORMAT='[[[%title%][ %album%][ %artist%]]|[%name%]|[%file%]]'
FIND_AUDIO_EXTENSIONS=( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.wma" -o -iname "*.wav" -o -iname "*.ogg" )
FUZZY=true
BLOCKING=false
EMPTY_EXECUTE=( 't' )

source "$SCRIPT_ROOT/scripts/notify.sh"

if [ ! -d "$AU_DIR" ]; then
    mkdir -p "$AU_DIR"
fi

library() {
    local WHAT="$1"
    shift
    [ -z "$*" ] && echo 'Search string cannot be empty!' >&2 && \
        return 2
    if [ "$SPECIFY_TYPE" ]; then
        $MPC "$WHAT" "${@}"
    else
        $MPC "$WHAT" any "$*"
        if [  ! "$MOPIDY" ]; then
            $MPC "$WHAT" filename "$*"
        fi
      fi
}

dir_browse() {
    local DIR
    if [ -f "$AU_DIR/LAST_BROWSE_DIR" ]; then
        DIR="$(cat "$AU_DIR/LAST_BROWSE_DIR")"
    else
        DIR="$MUSIC_DIR"
    fi
    {
        local SELECTED
        cd "$DIR" || return
        while true; do
            local DIR_LISTING
            DIR_LISTING="$( (
            echo .
            if [ "$DIR" != "$MUSIC_DIR" ]; then
                echo ..
            fi
            find . -maxdepth 1 \( -type d -o -type l -o -type f \( "${FIND_AUDIO_EXTENSIONS[@]}" \) \) -a -not -path '*/\.*' |\
                sed 's/^\.\///' | sed '/^\.$/d' | sort
            echo '. (no subdirectories)'
            echo '. (only subdirectories)'
            echo '. (all but specify excluded)'
            ) )"
            local SEL_LINE=0
            if [ -n "$SELECTED" ]; then
                SEL_LINE="$(echo "$DIR_LISTING" | grep -nFx "$SELECTED" |\
                    grep -oP '^\d+')"
                ((SEL_LINE--))
            fi
            local RESULT
            RESULT="$(echo "$DIR_LISTING" | "${BROWSER[@]}" -mesg "$( pwd )"\
                -selected-row "$SEL_LINE" 2>/dev/null || echo '' )"

            if [ -z "$RESULT" ]; then
                break;
            elif [ "$(wc -l <<< "$RESULT")" -le 1 ] &&  ! grep -q "^$RESULT"'$' <<< "$DIR_LISTING"; then
                continue
            else
                if [ "$( echo "$RESULT" | wc -l )" -gt 1 ]; then
                    RESULT="$( echo "$RESULT" | sed '/^\..*/d' )"
                    while read -r LINE; do
                        echo  "$DIR/$LINE"
                    done <<< "$RESULT"
                    break
                else
                    if [ "$RESULT" = '.' ]; then
                        find "$(pwd)" \( -type f -o -type l -xtype f \)\
                            -not -path '*/\.*' \( "${FIND_AUDIO_EXTENSIONS[@]}" \)
                        break

                    elif [ "$RESULT" = '. (no subdirectories)' ]; then
                        find "$(pwd)" -maxdepth 1 \( -type f -o -type l -xtype f \)\
                            -not -path '*/\.*' \( "${FIND_AUDIO_EXTENSIONS[@]}" \)
                        break

                    elif [ "$RESULT" = '. (only subdirectories)' ]; then
                        find "$(pwd)" -maxdepth 1 \( -type d -o -type l -xtype d \)\
                            -not -path '*/\.*' -not -path "$(pwd)"
                        break

                    elif [ "$RESULT" = '. (all but specify excluded)' ]; then
                        local ALL
                        ALL="$( {
                        find . \( -type d -o -type l -xtype d \) -not -path '*/\.*' | sort
                        find . \( -type f -o -type l -xtype f \)\
                            -not -path '*/\.*' \( "${FIND_AUDIO_EXTENSIONS[@]}" \) | sort
                        } | sed 's/^\.\///' | sed '/^\.$/d')"

                        while read -r LINE; do
                            # FORGIVE ME
                            LINE="$(escape_regex "$LINE")"
                            if [ -d "$LINE" ]; then # forgive me...
                                ALL="$( echo "$ALL" | sed "/^$LINE\\//d")"
                            fi
                            ALL="$( echo "$ALL" | sed "/^$LINE$/d")"
                        done <<< "$( echo "$ALL" |\
                            "${BROWSER[@]}" -mesg "Select all but... ($(pwd))" 2>/dev/null|| echo '')"

                        while read -r LINE; do
                            echo  "$DIR/$LINE"
                        done <<< "$ALL"
                        break
                    elif [ -d "$RESULT" ]; then
                        if [ "$RESULT" = '..' ]; then
                            SELECTED="$(basename "$DIR")"
                        else
                            SELECTED=''
                        fi
                        cd "$RESULT" || return
                        DIR="$(pwd)"
                    else
                        echo "$DIR/$RESULT"
                        break
                    fi
                fi
            fi
        done

        pwd > "$AU_DIR/LAST_BROWSE_DIR"
    } | sed "s/^$( escape_regex "$MUSIC_DIR/" )//"
}
pos_browse() {
    $MPC playlist -f "$PLAYLIST_FORMAT" | "${BROWSER[@]}" -mesg 'Playlist' -format d 2>/dev/null
}
escape_regex() {
    sed -e 's/[]\/()$*.^|[]/\\&/g' <<< "$1"
}
filter() {
    if [ "$NO_UNIQUE" ] || $CLEAR; then
        sort -u
    else
        sort -u | comm -23 - <($MPC playlist -f '%file%' | clean_output | sort -u)
    fi
}
pos_matching() {
    local LCOUNT_REL="${1:-$COUNT_REL}" SPACE=
    SPACE="$(cat)"
    shift
    local SEARCH="$*" OUT=1 LENGTH SPACE LINE
    local -a SARRAY
    LENGTH="$(wc -l <<< "$SPACE")"
    if [[ $SEARCH =~ ^[0-9]+: ]]; then
        OUT=${SEARCH%%:*}
        SEARCH="${SEARCH#*:}"
    elif [ -n "$COUNT" ]; then
        OUT="$COUNT"
    fi

    if [ "$COUNT_SGN" == '-' ]; then
        SPACE="$(tac <<< "$SPACE")"
        if [ -n "$LCOUNT_REL" ]; then
            LCOUNT_REL="$((LENGTH-COUNT_REL+1))"
        fi
    fi
    if [ -n "$LCOUNT_REL" ]; then
        LCOUNT_REL_IDX="$((LCOUNT_REL-1))"
        readarray -ts "$LCOUNT_REL_IDX" SARRAY
        readarray -tn "$LCOUNT_REL_IDX" -O "$LCOUNT_REL" SARRAY
        SPACE="$(printf '%s\n' "${SARRAY[@]}")"
    fi

    readarray -t SARRAY < <(grep -"$IGNORE_CASE"Fnm"$OUT" "$SEARCH" <<< "$SPACE")
    # shellcheck disable=2001
    [ "${#SARRAY[@]}" == 0 ] && "$FUZZY" && \
        readarray -t SARRAY < <(grep -"$IGNORE_CASE"Pnm"$OUT" "$(sed 's/./.*?[&]/g' <<< "$SEARCH").*?" <<< "$SPACE")
    LINE="${SARRAY[OUT-1]}"
    LINE="${LINE%%:*}"
    if [ -n "$LINE" ]; then
        [ -n "$LCOUNT_REL" ] && LINE="$((LINE+LCOUNT_REL-1))"
        LINE=$(((LINE-1)%LENGTH+1))
        [ "$COUNT_SGN" == '-' ] && LINE="$((LENGTH-LINE+1))"
    fi

    echo "$LINE"
    COUNT_REL='' COUNT_SGN='' COUNT=''
}
del_phrase() {
    local RES="" DATA LINE POS
    if [ "$ITEM" = 'tracks' ]; then
        DPOS="$(mpc status '%songpos%')"
    else
        DPOS=1
    fi
    DATA="$(cat)"
    while read -r TERM; do
        [[ $TERM =~ ^(([.,^$]?)([0-9]*):)?(.*) ]] || :
        local OCOUNT="$COUNT" OCOUNT_SGN="$COUNT_SGN"
        case "${BASH_REMATCH[2]}" in
            ^)
                COUNT_REL=
                COUNT_SGN=+
                ;;
            $)
                COUNT_REL=
                COUNT_SGN=-
                ;;
            .)
                COUNT_REL="$DPOS"
                COUNT_SGN=+
                ;;
            ,)
                COUNT_REL="$DPOS"
                COUNT_SGN=-
                ;;
        esac
        if [ -n "${BASH_REMATCH[3]}" ]; then
            BASH_REMATCH[3]="${BASH_REMATCH[3]}:"
        fi
        LINE="$(pos_matching '' "${BASH_REMATCH[3]}${BASH_REMATCH[4]}" <<< "$DATA")"
        RES="$RES$LINE-"
        COUNT="$OCOUNT" COUNT_REL="$((LINE+1))" COUNT_SGN="$OCOUNT_SGN"
    done < <(grep -o .<<<"$*"|sed -n '$!{/\\/{N;s/..//;H;b};/[^-]/{H;b};s/.//};$ H;x;s/\n\(.\)/\1/gp;s/.*//;x')
    echo "${RES:0:-1}"
    COUNT_REL='' COUNT_SGN='' COUNT=''
}
play_all() {
    local RESULT
    RESULT="$(sort -n)"
    local NUM=0
    local PLAY
    if [ -n "$RESULT" ]; then
        while read -r LINE; do
            if [ $NUM = 0 ]; then
                PLAY=$LINE
            else
                $MPC move "$LINE" $((PLAY+NUM))
            fi
            ((NUM++))
        done <<< "$RESULT"
        $MPC play "$PLAY"
    fi
}
clean_output() {
    # shellcheck disable=2059
    printf "$(sed 's/%\(..\)/\\x\1/g;s,[\%],&&,g')"
}
clean_html() {
    sed 's/&/&amp;/g;s/</\&lt;/g;s/>/\&gt;/g'
}
fetch_icon() {
    rm "$AU_DIR/current_cover" -f
    if mpc readpicture "$1" > "$AU_DIR/current_cover"; then
        return
    elif mpc albumart "$1" > "$AU_DIR/current_cover"; then
        return
    else
        rm "$AU_DIR/current_cover" -f
        # fallback
        local FILE
        FILE="$(clean_output <<< "$1")" DIR="${FILE%/*}"
        local FILE_REGEX='./\(cover\|folder\|titel\|album.*\).\(png\|jpe?g\|bmp\)'
        shopt -s nullglob
        if [ -f "$DIR/.cover_mpd.png" ]; then
            ln -sfr "$DIR/.cover_mpd.png" "$AU_DIR/current_cover"
            return
        elif [ -f "$DIR/.no_cover_found" ]; then
            return
        fi
        local UNSORTED
        UNSORTED="$(find "$DIR" -maxdepth 1 -iregex "$FILE_REGEX" )"
        if [ -n "$UNSORTED" ]; then
            FILE="$(grep  -iEm 1 'cover.(png|jpe?g)$' <<< "$UNSORTED")"
            [ -z "$FILE" ] && FILE="$(grep  -ivEm 1 'cover.(png|jpe?g)$' <<< "$UNSORTED")"
        else
            FILE="$(find "$DIR" \( -iname '*.mp3' -o -iname '*.ogg' -o -iname '*.flac' -o -iname '*.wav' -o -iname '*.wma' \) -print0 | head -zn1 )"
        fi
        if ffmpeg -i "$FILE" -vf scale="$ICON_RES" ".cover_mpd.png" &> /dev/null; then
            ln -sfr "$DIR/.cover_mpd.png" "$AU_DIR/current_cover"
        else
            touch "$DIR/.no_cover_found"
        fi
    fi
}
query_playing() {
    local PREFIX='' FILE
    if $BLOCKING; then
        PREFIX='(!) '
    fi
    FILE="$(mpc -f '%file%' current)"
    if [ -z "$FILE" ]; then
        rm -f "$AU_DIR/current_cover"
        notify -u low "$PREFIX"'No track playing' -a "$PROVIDER"
        return
    fi
    fetch_icon "$FILE"
    local ICON_ARG=()
    if [ -e "$AU_DIR/current_cover" ]; then
        ICON_ARG=( '-i' "$AU_DIR/current_cover" )
    fi

    local SUMMARY
    local BODY
    local APP
    if [ -z "$( mpc -f '[%title%]|[%name%]' current )" ]; then
        SUMMARY="${FILE##*/}"
        SUMMARY="${SUMMARY%.*}"
        BODY="${FILE%/*}"
        APP='noxgrim:audio:unknown'
    else
        SUMMARY="$( mpc -f '[%title%]|[%name%]' current )"
        BODY="$( mpc -f '[[%artist% • ][%album%]|[<i>Unknown</i>]]|[<i>Unknown</i>]' \
            current )"
    fi

    notify -a "$APP" "${ICON_ARG[@]}" -a "$PROVIDER" -- "$PREFIX$SUMMARY" "$(clean_html <<< "$BODY")"
}
change_notify() {
    if [ -f "$AU_DIR/AUDIO_LOOP_PID" ]; then
        xargs kill -SIGKILL < "$AU_DIR/AUDIO_LOOP_PID"
        notify -u low 'Stopped change notifications!' -a "$PROVIDER"
        rm "$AU_DIR/AUDIO_LOOP_PID"
    else
        (
        while [[ "$( mpc 2>&1 >/dev/null )" == *"Connection refused"* ]]; do
            sleep 0.5; done
        notify -u low 'Started change notifications!' -a "$PROVIDER"

        while true; do
            if [ -z "$( mpc -f '%time%' current )" ]; then #Stream
                $MPC idle player
            else
                mpc current --wait &> /dev/null
            fi
            if [ ! -e "$AU_DIR/AUDIO_DO_NOT_QUERY" ]; then
                query_playing
            fi

            if [[ "$( mpc current &>/dev/null )" ==\
                  *"Connection refused"* ]]; then
                notify -u critical 'Stopped change notifications!' \
                    "Mpc couldn't connect to $PROVIDER_NAME. $PROVIDER_NAME most likely died." -a "$PROVIDER"
                kill "$(pgrep "$PROVIDER")" && echo "Killed $PROVIDER_NAME!"
                rm "$AU_DIR/AUDIO_LOOP_PID"
                break
            fi

        done
        ) & disown && echo $! > "$AU_DIR/AUDIO_LOOP_PID"
    fi
}
handle_play() {
    if [ "$(mpc status '%state%')" == 'playing' ]; then
        (
        systemd-inhibit --why "Playing audio" --what=idle:handle-lid-switch \
            --who audio sleep infinity&
        PID=$!
        touch "$AU_DIR/BLOCKING"
        while $MPC idle player &>/dev/null; do
            if [ "$(mpc status '%state%')" != 'playing' ]; then
                break
            fi
        done
        kill $PID || true
        rm -f "$AU_DIR/BLOCKING"
    )& disown
    else
        BLOCKING=false
    fi
}

ARGS_START=1
AUTOSTART=1
IGNORE_CASE="i"

if [ "$#" = 0 ]; then
    set -- "${EMPTY_EXECUTE[@]}"; # Special case because most used; Reset to preserve behavior
fi

for ARG in "$@"; do
    if [[ "$ARG" =~ ^-.+$ ]]; then
        case "$ARG" in
            --no-autostart|-n)
                AUTOSTART=0
                ;;
            --provider|-p)
                PROVIDER_PENDING=1
                ;;
            --specify-type|-s)
                SPECIFY_TYPE=1
                ;;
            --regard-case|-I)
                IGNORE_CASE=""
                ;;
            --no-unique|-U)
                NO_UNIQUE=1
                ;;
            --deactivate-change-notifications|-C)
                NO_CHANGE_NOTIFY=1
                ;;
            --ignore-change-notifications|-c)
                NO_CHANGE_NOTIFY=1
                SKIP_CHANGE_NOTIFY=1
                ;;
            --help|-h)
                cat << EOF
$0 Help
A wrapper script that makes the use of mpd or mopidy and mpc easier
and allows multitasking. Because the script can work with either mpd or
mopidy they will be referred to as 'providers'.
$0 [OPTION]... COMMANDS [ARGUMENTS]...

Commands:
 Commands control what tasks the script performs. Multiple commands must
 be written in a string (e.g. jjp) with the arguments following after that.
 The arguments will be associated with the commands that accessed them
 accordingly. The search query commands (s, f) will always accept the
 remaining arguments.

 Some commands can be prefixed by an (optionally signed) <count>, e.g '+5'.
 A count which is not used by any command acts like <count>p.

  . make <count> relative to current track instead of absolute to the playlist
    start and ends
  L act on playlists instead of tracks
    Saves the current playlist under the name of given by all remaining
    arguments when used alone

 Control:
  p mpc play <count>
    if count negative, relative to end of playlist or subtracted from position
    of the current track
  t mpc toggle
  k mpc prev
    accepts <count> (but ignores '.'), can be used multiple times
  j mpc next
    accepts <count> (but ignores '.'), can be used multiple times
  r mpc repeat
  x mpc shuffle
  X mpc random
  o mpc single (mnemonic Only)
  c mpc clear
  v [arg]
    mpc volume [arg]
    uses <count> or '100' if [arg] not given
  g [arg]
    mpc seek [arg] (mnemonic Goto)
    uses <count> or '0' if [arg] not given
  h mpc stop (mnemonic Halt)
  B mpc pause (mnemonic Break)
  q display a notification with the current title, artist and album; will
     also be displayed if automatic notifications are disabled
  i mpc status
  # mpc stats
  K kill PROVIDER (executed immediately)
  y mpc update --wait
  Q toggle the automatic displaying of a notification if the p, t, h, B, j, k
     commands are used
  C toggle change notifier loop
  ! if playing, make play blocking 'idle:handle-lid-switch'
     until pausing again

 Search Targets/Handlers (mutually exclusive):
  - (none)
    - play result in current playlist
    L add matching playlist(s)
  a add results
    - add results to current playlist
    L add matching playlist(s)
  d delete results
    - remove results to from current playlist
    L remove matching playlist(s) from disk

    Extends the search syntax:
      * it is possible to define a single range with '-' (which can be escaped
          with '\\')
      * <count> applies to all terms
      * the second term begins from the first+1 (as value for '.')
      * using '.<count>:' is the same as specifying count '.+<count>' for that
        term
      * using ',<count>:' is the same as specifying count '.-<count>' for that
        term
      * using '^<count>:' is the same as specifying count '+<count>' for that
        term, '.' is ignored
      * using '$<count>:' is the same as specifying count '-<count>' for that
        term, '.' is ignored
  l print (list) results

 Searching (mutually exclusive):
  s search fuzzily current in playlist, playlists or invoke mpc search
    When used on tracks, the following applies:
    * <count> or term prefixed with '<count>:' return <count>th match
    * negative count searches from the end of the playlist(s)
    * '.' starts search from current track
  f same as 's' but search non-fuzzily or invoke mpc find
  b Browse current playlist or music directory.
    Tracks in the current playlist are moved below the first match, if multiple
    are selected to be played.


Options: [these are only accepted before the commands!]
  -c  --skip-change-notifications
                     Do not automatically activate change notifications this
                      time. The next time the command is issued without this
                      switch automatically enable them again. Useful for
                      use in scripts or key bindings.
  -C --deactivate-change-notifications
                     Disable automatic activation of change notifications
                      on first startup and deactivate them like using the 'C'
                      command. Use the 'C' command to enable them again.
  -h, --help         display this help and exit
  -I, --regard-case  do not ignore case when searching with 'sdf'
  -n  --no-autostart do not start mpd or mopidy automatically if they are not
                      running
  -p  --provider [provider]
                     specify the provider. Supported: mpd, mopidy; default: $PROVIDER
  -s, --specify-type Specify the type of search queries yourself.
                      The type is set to 'any' if this parameter is
                      omitted and all subsequent arguments will be
                      joined into a single query.
                      Possible types are:
                       album     any       artist    comment   composer
                       date      disc      filename  genre     name
                       performer title     track
  -U, --no-unique    also add titles if they are already in the current
                      playlist
  --                 stop arguments

Note: if neither options nor commands are specified the script will execute
      '${EMPTY_EXECUTE[@]}'.
EOF
                exit 0
                ;;
            --)
                ((ARGS_START++))
                break 2
                ;;
            -[0-9]*)
                break 2
                ;;
            *)
                echo "Unknown option: $ARG"
                exit 1
        esac
        ((ARGS_START++))
    else
        if [ "$PROVIDER_PENDING" ]; then
            PROVIDER_PENDING=
            PROVIDER="$ARG"
            ((ARGS_START++))
        else
            break
        fi
    fi
done

case "$PROVIDER" in
    mpd)
        PROVIDER_NAME='MPD'
        ;;
    mopidy)
        PROVIDER_NAME='Mopidy'
        ;;
    *)
        echo "Unknown provider: $PROVIDER"
        exit 1
        ;;
esac

if [ ! "$( pgrep "$PROVIDER" )" ] && [ ! "$AUTOSTART" ]; then
    echo "$PROVIDER_NAME not running!"
    exit 1
elif [ ! "$( pgrep "$PROVIDER" )" ]; then
    notify "Starting $PROVIDER_NAME!" -a 'audio'
    case "$PROVIDER" in
        mpd)
            systemctl --user restart mpd.service
            ;;
        mopidy)
            mopidy &> "$AU_DIR/mopidy.log"& disown
            # [ ! "$NO_CHANGE_NOTIFY" ] && change_notify # Do we really need this?
            ;;
    esac
    while [[ "$( mpc 2>&1 >/dev/null )" == *"Connection refused"* ]]; do
        sleep 0.5 ; done # Wait for provider to respond properly.
fi

if [ ! "$NO_CHANGE_NOTIFY" ] && [ ! -f "$AU_DIR/ATTEMPTED_LOOP" ]; then
    change_notify
fi
if [ ! -f "$AU_DIR/ATTEMPTED_LOOP" ] && [ ! "$SKIP_CHANGE_NOTIFY" ]; then
    touch "$AU_DIR/ATTEMPTED_LOOP"
fi

# The juicy stuff

COUNT=
COUNT_REL=
COUNT_SGN=
SHIFT=0
CLEAR=false
SHUFFLE=false
ACTION=
PLAY_ACTION=
SEARCH_OPTION=
INFORM=
ITEM=tracks

COMMAND="${!ARGS_START}"
((ARGS_START++))
while read -r C; do
    case "$C" in
        [0-9])
            [ -z "$COUNT" ] && COUNT=0
            COUNT=$((COUNT*10+C))
            ;;
        .)
            COUNT_REL="$(mpc status '%songpos%')"
            COUNT=
            ;;
        [+-])
            COUNT_SGN="${C}"
            COUNT=
            ;;
        p)
            PLAY_ACTION=play
            ;&
        t)
            PLAY_ACTION=${PLAY_ACTION:-toggle}
            ;&
        h)
            PLAY_ACTION=${PLAY_ACTION:-stop}
            ;&
        B)
            PLAY_ACTION=${PLAY_ACTION:-pause}
            if [ "$(mpc status '%state')" != stopped ] ||\
                 [ ! -f "$AU_DIR/AUDIO_LOOP_PID" ]; then
                QUERY=1
            fi
            ;;
        '!')
            BLOCKING=true
            ;;
        k)
            DIRECTION=-1
            ;&
        j)
            [ -z "$COUNT" ] && COUNT=1
            # shellcheck disable=2211,1102
            SHIFT="$((SHIFT+"${DIRECTION:-1}"*COUNT"${COUNT_SGN:+"*${COUNT_SGN}1"}"))"
            COUNT=
            COUNT_REL=
            COUNT_SGN=
            if [ ! -f "$AU_DIR/AUDIO_LOOP_PID" ]; then
                QUERY=1
            fi
            ;;
        q)
            QUERY=2
            ;;
        Q)
            # How to efficiency set an environment variable globally across
            # different and future terminals?
            if [ -e "$AU_DIR/AUDIO_DO_NOT_QUERY" ]; then
                rm "$AU_DIR/AUDIO_DO_NOT_QUERY"
            else
                touch "$AU_DIR/AUDIO_DO_NOT_QUERY"
            fi
            ;;
        i)
            INFORM=1
            ;;
        '#')
            STATS=1
            ;;
        C)
            change_notify
            ;;
        K)
            if [ -f "$AU_DIR/AUDIO_LOOP_PID" ]; then
                change_notify
            fi
            kill "$(pgrep "$PROVIDER")" && echo "Killed $PROVIDER_NAME!"
            exit 0
            ;;
        y)
            UPDATE=1
            ;;

        r)
            $MPC repeat
            ;;
        X)
            $MPC random
            ;;
        o)
            $MPC single
            ;;
        x)
            SHUFFLE=true
            ;;
        c)
            CLEAR=true
            ;;
        v)
            VOLUME=${!ARGS_START:-"${COUNT_SGN:-}${COUNT:-100}"}
            if [ -z "${!ARGS_START:-}" ]; then
                COUNT=
                COUNT_REL=
                COUNT_SGN=
            else
                ((ARGS_START++))
            fi
            case "$VOLUME" in
                [+-]*);;
                *)
                    [ "$VOLUME" -gt 100 ] && VOLUME=100
            esac
            $MPC volume "$VOLUME"
            VOLUME="$(mpc status '%volume%')"
            VOLUME="${VOLUME## }"
            notify -a 'noxgrim:volume' -u low -h "int:value:${VOLUME%'%'}"\
                "$PROVIDER volume " '%'
            ;;
        g)
            SEEK=${!ARGS_START:-"${COUNT_SGN:-}${COUNT:-0}"}
            if [ -z "${!ARGS_START:-}" ]; then
                COUNT=
                COUNT_REL=
                COUNT_SGN=
            else
                ((ARGS_START++))
            fi
            ;;

        a)
            ACTION=add
            ;;
        l)
            ACTION=list
            ;;
        d)
            ACTION=delete
            ;;

        s)
            SEARCH_OPTION=search
            ;;
        f)
            SEARCH_OPTION='find'
            ;;
        b)
            SEARCH_OPTION=browse
            ;;
        L)
            ITEM=playlists
            ;;

        *)
            echo "$C is not a valid command."
            echo 'Valid commands: abcdfghijklopqrstvxyzBCKLQX!#'
            echo 'See -h for more info.'
            exit 1
    esac
done < <(grep -o . <<< "$COMMAND")

PREV_LENGTH="$(mpc status '%length%')"
if $CLEAR && [ "$PREV_LENGTH" == 0 ]; then
    CLEAR=false
fi

# Non-stackable commands
if [ "$UPDATE" ]; then
    $MPC update --wait
    notify -u low 'Updated database.' -a "$PROVIDER"
fi

case "$ITEM" in
    playlists)
        mpc lsplaylists |\
            case "$SEARCH_OPTION" in
                search|find)
                    del_phrase "${@:$ARGS_START}" 2> /dev/null
                    ;;
                browse)
                    "${BROWSER[@]}" -mesg 'Playlists to '"$ACTION" -format d 2>/dev/null
                    ;;
                *)
                    case "$ACTION" in
                        list)
                            seq "$(wc -l)"
                            ;;
                        add|delete)
                            "${BROWSER[@]}" -mesg 'Playlists to '"$ACTION" -format d 2>/dev/null
                            ;;
                        *)
                            mpc save "${@:$ARGS_START}"
                    esac
                    ;;
            esac |\
            sed 's/$/p/' | tr '\n' ';' | xargs -I{} -r sed -n {} <(mpc lsplaylists) |\
            case "$ACTION" in
                list)
                    cat
                    ;;
                add)
                    mpc load >/dev/null
                    ;;
                delete)
                    xargs -rn 1 mpc rm
                    ;;
            esac
        case "$SEARCH_OPTION" in
            find|search) COUNT_REL='' COUNT_SGN='' COUNT=''
        esac
        case "$ACTION" in
            delete) $CLEAR && CLEAR=false
        esac
        ;;
    tracks)
        case "$ACTION" in
            add|list)
                case "$SEARCH_OPTION" in
                    search|find)
                        library "$SEARCH_OPTION" "${@:$ARGS_START}" | filter
                        ;;
                    browse)
                        dir_browse "${@:$ARGS_START}" | filter
                        ;;
                    *)
                        case "$ACTION" in
                            add)
                                T="${*:$ARGS_START}"
                                if [ -z "$T" ]; then
                                    echo 'Item to add may not be empty!' >&2 && exit 1
                                fi
                                echo "$T"
                                ;;
                            list)
                                mpc playlist -f "$PLAYLIST_FORMAT"
                                ;;
                        esac
                esac | case "$ACTION" in
                    add)
                        mpc add
                        ;;
                    list)
                        cat
                        ;;
                esac
                ;;
            delete)
                $CLEAR && CLEAR=false
                case "$SEARCH_OPTION" in
                    find)
                        FUZZY=false
                        ;&
                    search|'')
                        mpc playlist -f "$PLAYLIST_SEARCH_FORMAT" | clean_output | del_phrase "${@:$ARGS_START}"
                        ;;
                    browse)
                        mpc playlist -f "$PLAYLIST_FORMAT" | clean_output | pos_browse
                        ;;
                esac | mpc del
                case "$SEARCH_OPTION" in
                    find|search) COUNT_REL='' COUNT_SGN='' COUNT=''
                esac
                ;;
            *)
                case "$SEARCH_OPTION" in
                    find)
                        FUZZY=false
                        ;&
                    search)
                        mpc playlist -f "$PLAYLIST_SEARCH_FORMAT" | clean_output | pos_matching '' "${@:$ARGS_START}"
                        ;;
                    browse)
                        pos_browse
                        ;;
                esac | play_all
                case "$SEARCH_OPTION" in
                    find|search) COUNT_REL='' COUNT_SGN='' COUNT=''
                esac
                ;;
        esac
        ;;
esac

LENGTH="$(mpc status '%length%')"
if [ "$PREV_LENGTH" == "$LENGTH" ]; then
    case "$ACTION" in
        delete)
            if [ "$ITEM" != playlists ]; then
                echo 'Nothing found.'
            fi
            ;;
        add)
            echo 'Nothing found.'
            :
    esac
fi


STATE="$(mpc status '%state%')"
if $CLEAR; then
    if [ "$PREV_LENGTH" == "$LENGTH" ]; then
        if [ -z "${ACTION:-}" ] || [ "$ACTION" == list ]; then
            $MPC clear
        fi
    else
        if [ "$STATE" != stopped ]; then
            if $SHUFFLE; then
                $MPC play $((PREV_LENGTH+RANDOM%(LENGTH-PREV_LENGTH)+1))
            else
                $MPC play $((PREV_LENGTH+1))
            fi
        fi
        CHANGED=true
        $MPC del "1-$PREV_LENGTH"
        $SHUFFLE && $MPC shuffle
    fi
elif $SHUFFLE; then
    $MPC shuffle
fi

if [ "${SHIFT:-0}" != 0 ]; then
    POS="$(mpc status '%songpos%')"
    LENGTH="$(mpc status '%length%')"
    POS="$((POS+SHIFT))"
    [ $POS -lt 1 ] && POS=1
    [ $POS -gt "$LENGTH" ] && POS="$LENGTH"
    $MPC play "$POS"
    CHANGED=true
fi

if [ -n "${SEEK:-}" ]; then
    CHANGED=true
    case "$SEEK" in
        [+-]*%)
            $MPC seek "$SEEK"
            ;;
        [+-]*)
            $MPC seekthrough "$SEEK"
            ;;
        *)
            $MPC seek "$SEEK"
    esac
fi
if "${CHANGED-false}"; then
    [ "$STATE" == paused ] && $MPC pause
    [ "$STATE" == stopped ] && $MPC stop
fi

[ -n "$COUNT" ] && [ -z "${PLAY_ACTION:-}" ] && PLAY_ACTION=play

case "$PLAY_ACTION" in
    play)
        if [ -n "$COUNT" ]; then
            POS="$COUNT_SGN$COUNT"
            LENGTH="$(mpc status '%length%')"
            if [ -n "$COUNT_REL" ]; then
                POS=$((COUNT_REL+COUNT))
            elif [ "$POS" -lt 0 ]; then
                POS=$((LENGTH-POS+1))
            fi
            [ "$POS" -lt 1 ] && POS=1
            [ "$POS" -gt "$LENGTH" ] && POS="$LENGTH"
            $MPC play "$POS"
        else
            $MPC play
        fi
        ;;
    toggle|stop|pause)
        $MPC "$PLAY_ACTION"
        ;;&
    stop)
        rm "$AU_DIR/current_cover"
        ;;
esac
if [ "$INFORM" ]; then
    mpc status
fi
if [ "$STATS" ]; then
    mpc stats
fi
if $BLOCKING; then
    handle_play
fi
if [ -n "$QUERY" ] && [ ! -e "$AU_DIR/AUDIO_DO_NOT_QUERY" ] ||\
    [ "$QUERY" = 2 ]; then
    query_playing
fi

