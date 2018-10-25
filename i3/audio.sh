#! /bin/bash

MPC='mpc -q'
BROWSER=( rofi -dmenu --only-match -i -multi-select -p 'Browse: ')
AU_DIR='/tmp/audio_control'
PROVIDER='mpd'
MPD_CONF="$HOME/.mpdconf"
MPD_HOST="$(grep -Po '(?<=^password ")[^@]*' "$MPD_CONF")@localhost"
export MPD_HOST
MUSIC_DIR="$(grep 'music_directory' "$MPD_CONF" | grep -oP '(?<=").*?(?=")' |\
    sed -r "s/~/$( sed 's/[&/\]/\\&/g' <<<"$HOME"  )/" )"
ICON_RES='80:80' #Only affects newly created icons
RADIO_QUERY_RES=5
#PLAYLIST_FORMAT='%position%. %artist% • %title%'
PLAYLIST_FORMAT='%position%. [[%artist% • ][%title%]|[%filename%]]'
FIND_AUDIO_EXTENSIONS=( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.wma" -o -iname "*.wav" -o -iname "*.ogg" )
EMPTY_EXECUTE=( 't' )

if [ ! -d "$AU_DIR" ]; then
    mkdir "$AU_DIR"
fi

m_search() {
  if [ ! "$#" ]; then
      echo 'Search string cannot be empty!'
  else
      if [ "$SPECIFY_TYPE" ]; then
          $MPC search "${@}"
      else
          $MPC search any "$*"
          if [  ! "$MOPIDY" ]; then
              $MPC search filename "$*"
          fi
      fi
  fi
}
m_find() {
  if [ ! "$#" ]; then
      echo 'Find string cannot be empty!'
  else
      if [ "$SPECIFY_TYPE" ]; then
          $MPC find "${@}"
      else
          $MPC find any "$*"
          if [  ! "$MOPIDY" ]; then
              $MPC find filename "$*"
          fi
      fi
  fi
}

m_browse() {
    local DIR
    if [ -f "$AU_DIR/LAST_BROWSE_DIR" ]; then
        DIR="$(cat "$AU_DIR/LAST_BROWSE_DIR")"
    else
        DIR="$MUSIC_DIR"
    fi
    (
        local SELECTED
        cd "$DIR" || return
        while true; do
            local DIR_LISTING
            DIR_LISTING="$( (
            echo .
            if [ "$DIR" != "$MUSIC_DIR" ]; then
                echo ..
            fi
            find . -maxdepth 1 \( -type d -o -type l -o -type f \( -iname '*.mp3' \
                -o -iname '*.flac' -o -iname '*.wma' \) \) -a -not -path '*/\.*' |\
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
                -selected-row "$SEL_LINE" || echo '' )"

            if [ -z "$RESULT" ]; then
                break;
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
                        ALL="$( (
                        find . \( -type d -o -type l -xtype d \) -not -path '*/\.*' | sort
                        find . \( -type f -o -type l -xtype f \)\
                            -not -path '*/\.*' \( "${FIND_AUDIO_EXTENSIONS[@]}" \) | sort
                        ) | sed 's/^\.\///' | sed '/^\.$/d')"

                        while read -r LINE; do
                            # FORGIVE ME
                            LINE="$(escape_regex "$LINE")"
                            if [ -d "$LINE" ]; then # forgive me...
                                ALL="$( echo "$ALL" | sed "/^$LINE\\//d")"
                            fi
                            ALL="$( echo "$ALL" | sed "/^$LINE$/d")"
                        done <<< "$( echo "$ALL" |\
                            "${BROWSER[@]}" -mesg "Select all but... ($(pwd))"\
                            || echo '')"

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
    ) | sed "s/^$( escape_regex "$MUSIC_DIR/" )//"
}
pl_browse() {
    local CURRENT_PL
    CURRENT_PL="$( $MPC playlist -f "$PLAYLIST_FORMAT" )"
    local SELECTED
    SELECTED="$( echo "$CURRENT_PL" | "${BROWSER[@]}" -mesg 'Playlist' || echo '' )"
    local NUM=1
    while read -r LINE; do
        if echo "$SELECTED" | grep -qFx "$LINE"; then
            echo $NUM
        fi
        ((NUM++))
    done <<< "$CURRENT_PL"
}
escape_regex() {
    sed -e 's/[]\/()$*.^|[]/\\&/g' <<< "$1"
}
filter() {
    if [ "$NO_UNIQUE" ]; then
        sort -u
    else
        TEMP="$(sort -u)"
        $MPC -f '%file%' playlist | sort -o "$AU_DIR/CURR_PL"
        echo "$TEMP" | comm -23 - "$AU_DIR/CURR_PL"
        rm "$AU_DIR/CURR_PL"
    fi
}
pos_matching() {
    local SEARCH="$*"
    local OUT=1
    if echo "$SEARCH" | grep -qP '^\d+:'; then
        OUT="$( echo "$SEARCH" | grep -oP '^\d+' )"
        SEARCH="$( echo "$SEARCH" | sed -r 's/^[0-9]+:(.*?$)/\1/' )"
    fi
    local NUM=1
    mpc playlist | clean_output |\
        while read -r TRACK; do
            if echo "$TRACK" | grep -"$IGNORE_CASE"qP "$SEARCH"; then
                ((OUT--))
                if [ "$OUT" -lt 1 ]; then
                    echo "$NUM"
                    break
                fi
            fi
            ((NUM++))
        done
}
pl_add() {
  if [ ! "$#" ]; then
      echo 'Search string cannot be empty!'
  else
      local SEARCH="$*"
      while read -r LIST; do
        if echo "$LIST" | grep -"$IGNORE_CASE"qP "$SEARCH"; then
            $MPC load "$LIST" > /dev/null
            return
        fi
        done  < <( $MPC lsplaylists )
        notify-send -u low 'No matching playlist found!'
  fi
}
del_num() {
    echo "$@" | sed "s/\./$( mpc -f '%position%' current)/g" |\
        sed "s/\\$/$( mpc playlist | wc -l )/g" | sed -r 's/\s+/\n/g'
}
del_phrase() {
    for ARG in "$@"; do
        local RES=""
        while read -r TERM; do
            if echo "$TERM" | grep -qP '^\\(?!\\)'; then
                TERM=$(echo "$TERM" | sed -r 's/\\(.)/\1/g')
                RESULT=$( del_num "$TERM" )
            else
                TERM=$(echo "$TERM" | sed -r 's/\\(.)/\1/g')
                RESULT="$( pos_matching "$TERM" )"
            fi
            if [ -z "$RESULT" ]; then
                RES="$RES?-"
            else
                RES="$RES$RESULT-"
            fi
        done < <( echo "$ARG" | grep -oE '(\\(?!\\)-|[^-])*?' |\
            sed 's/\\-/-/g' | head -n 2 )
        # Use 'process substitution' to access variable
        # outside of loop
        echo "${RES:0:-1}"
    done
}
play_all() {
    local RESULT
    RESULT="$(pl_browse || sort -n)"
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
    local OUT
    OUT="$(sed 's/%\(..\)/\\x\1/g')"
    echo -e "$OUT"
}
query_playing() {
    sleep 0.1 # Wait until mopidy or mpd update their indices
    if [ -z "$( mpc current )" ]; then
        notify-send -u low 'No track playing'
    elif [ -z "$( mpc -f '%time%' current )" ]; then # Most probably a radio station
        notify-send "$( mpc -f '%title%' current | clean_html )"\
            "$( mpc -f '%name%' current | clean_html )"
    else
        local CURRENT
        CURRENT="$( mpc -f "%file%" current | clean_output )"
        local DIR
        DIR="$( dirname "$CURRENT" )"
        local ICON_ARG=()
        check_icon "$MUSIC_DIR/$DIR"
        if [ -f "$MUSIC_DIR/$DIR/.cover_mpd.png" ]; then
            ln -sfr "$MUSIC_DIR/$DIR/.cover_mpd.png" "$AU_DIR/current_cover"
            ICON_ARG=( '-i' "$AU_DIR/current_cover" )
        else
            ICON_ARG=( '--' )
        fi

        local SUMMARY
        local BODY
        if [ -z "$( mpc -f '%title%' current )" ]; then
            SUMMARY="<i>$( basename "$CURRENT" '.mp3')</i>"
            BODY="$DIR"
        else
            SUMMARY="$( mpc -f '%title%' current )"
            BODY="$( mpc -f '[[%artist% • ][%album%]|[<i>Unknown</i>]]|[<i>Unknown</i>]' \
                current )"
        fi

        SUMMARY="$(echo "$SUMMARY" | clean_html)"
        BODY="$(echo "$BODY" | clean_html)"

        notify-send "$SUMMARY" "$BODY" "${ICON_ARG[@]}"
    fi
}
clean_html() {
    sed 's/&/&amp;/g' |\
    sed 's/</\&lt;/g' | sed -r 's/&lt;(\/?\w+>)/<\1/g' |\
    sed 's/>/\&gt;/g' | sed -r 's/(<\/?\w+)&gt;/\1>/g'
}
check_icon() {
    (
        cd "$1" || return
        local FILES=
        shopt -s nullglob
        if [ -f ".cover_mpd.png" ] || [ -f ".no_cover_found" ]; then
            return
        elif [ -f cover.png ] || [ -f cover.jpg ] || [ -f cover.jpeg ]; then
            FILES=( cover.png* cover.jpg* cover.jpeg* )
        else
            FILES=( *.mp3 *.flac *.wma *.wav *.ogg )
        fi
        if ! ffmpeg -i "${FILES[0]}" -vf scale="$ICON_RES" ".cover_mpd.png" &> /dev/null; then
            touch ".no_cover_found"
        fi
    )
}
change_notify() {
    local LAST=
    if [ -f "$AU_DIR/AUDIO_LOOP_PID" ]; then
        xargs kill -SIGKILL < "$AU_DIR/AUDIO_LOOP_PID"
        notify-send -u low 'Stopped change notifications!'
        rm "$AU_DIR/AUDIO_LOOP_PID"
    else
        (
        while [[ "$( mpc 2>&1 >/dev/null )" == *"Connection refused"* ]]; do
            sleep 0.5; done
        notify-send -u low 'Started change notifications!'

        while true; do
            if [ -z "$( mpc -f '%time%' current )" ]; then #Stream
                sleep "$RADIO_QUERY_RES"
                if [ ! -e "$AU_DIR/AUDIO_DO_NOT_QUERY" ] &&\
                     [ "$( mpc -f '%title%' current )" != "$LAST" ]; then
                    query_playing
                    LAST="$( mpc -f '%title%' current )"
                fi
            else
                mpc current --wait &> /dev/null
                if [ ! -e "$AU_DIR/AUDIO_DO_NOT_QUERY" ]; then
                    query_playing
                fi
            fi

            if [[ "$( mpc current &>/dev/null )" ==\
                  *"Connection refused"* ]]; then
                notify-send -u critical 'Stopped change notifications!' \
                    "Mpc couldn't connect to $PROVIDER_NAME. $PROVIDER_NAME most likely died."
                kill "$(pgrep $PROVIDER)" && echo "Killed $PROVIDER_NAME!"
                rm "$AU_DIR/AUDIO_LOOP_PID"
                break
            fi

        done
        ) & disown && echo $! > "$AU_DIR/AUDIO_LOOP_PID"
    fi
}

ARGS_START=1
AUTOSTART=1
IGNORE_CASE="i"

if [ "$#" = 0 ]; then
    set -- "${@}" "${EMPTY_EXECUTE[@]}"; # Special case because most used; Reset to preserve behavior
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
A simple wrapper script that makes the use of mpd or mopidy and mpc easier
and allows multitasking. Because the script can work with either mpd or
mopidy they will be refered to by the name 'provider'.
$0 [OPTION]... COMMANDS

Commands:
 Commands control what tasks the script performs. Multiple commands must
 be written in a string (e.g. JJp) with the arguments following after that.
 The arguments will be associated with the commands that accessed them
 accordingly. The search query commands (s, f) will always accept the
 remaining arguments.

 Non-stackable: (Last specified will be executed if mutually exclusive;
                 Last to be executed)
  p mpc play
  t mpc toggle
  h mpc stop (mnemonic Halt)
  b mpc pause (mnemonic Break)
  q Display a notification with the current title, artist and album; will
     also be displayed if automatic notifications are disabled
  i mpc status
  # mpc stats
  D [args]
    mpc [args] (mnemonic mpc Do; Executes a mpc query; Overrides a search/handler)
  k kill PROVIDER (executed immediately)
  Y mpc update --wait

 Stackable:
  K mpc prev
  J mpc next
  Q Toggle the automatic displaying of a notification if the p, t, h, b, J, K
     commands are used
  r mpc repeat
  z mpc random
  y mpc single
  x mpc shuffle
  c mpc clear
  v [arg]
    mpc volume [arg]
  S [arg]
    mpc seek [arg]
  C Toggle change notifier loop

 Searching: (Can be used with a handle command; Always uses all remaining arguments;
  Last specified will be executed)
  s mpc search
  f mpc find
  P Search for track in the playlist by name and play it. To reference the N-th
     occurrence use 'N:<search term>'. Will be ignored when used with a or l.
  L Reference a playlist.
  B Browse the music directory or current playlist.

 Handling:
  a Add results.
    Acts like 'mpc add [search results]' when used with s, f or B
    Acts like 'mpc load [pl name]'       when used with L
    Acts like 'mpc add [args]'           when used alone or with P
  l List results.
    Acts like 'echo [search results]'    when used with s, f or B
    Acts like 'mpc lsplaylists'          when used with L
    Acts like 'mpc playlist'             when used alone or with P
  d Delete results
    Acts like 'mpc del [args]'           when used with P or B
     Special values: $  last playlist element
                     .  current playlist element
    Behaviour                            when used with s or f
     Search for each text occurrence of elements (may be separated by '-' to
      indicate a range). The syntax of 'play matching track P' is used. To
      behave like 'delete by number P' the element can be preceded by a '\\'.
      Every '\\' escapes the character in front of it, so it is possible to
      escape the range meaning of '-'. It is not possible to use whitespace in
      the patterns in the current implementation. :(
      Example:
        roses-violets forget\\-me\\-not-\\$
    Acts like 'mpc rm \"[args]\"'        when used with L

  - (No handling operator)
    Plays matching song                  when P
    Plays first matching song            when B
     and moves all other matches beneath
     the first matching song
    Acts like 'mpc save [new pl name]'   when L

Options: [these only accepted before the commands!]
  -c  --skip-change-notifications
                     Do not automatically activate change notifications this
                      time. The next time the command is issued without this
                      switch do automatically enable them again. Usefull for
                      use in scripts or key bindings.
  -C --deactivate-change-notifications
                     Disable automatic activation of change notifications
                      on first startup and deactivate them like using the 'C'
                      command. Use the 'C' command to enable them agian.
  -h, --help         display this help and exit
  -I, --regard-case  do not ignore case when searching with 'P'
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
            *)
                echo "Unknown option: $ARG"
                exit 1
        esac
        ((ARGS_START++))
    else
        if [ $PROVIDER_PENDING ]; then
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
    notify-send "Starting $PROVIDER_NAME!"
    case "$PROVIDER" in
        mpd)
            mpd "$HOME/.mpdconf"
            ;;
        mopidy)
            mopidy &> "$AU_DIR/mopidy.log"&disown
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

COMMAND="${!ARGS_START}"
((ARGS_START++))
for C in $( echo $COMMAND | grep -o . ); do
    case "$C" in
        p)
            PLAY_ACTION=1
            if [ "$( mpc status | wc -l )" -gt 1 ] ||\
                 [ ! -f "$AU_DIR/AUDIO_LOOP_PID" ]; then
                QUERY=1
            fi
            ;;
        t)
            PLAY_ACTION=2
            if [ "$( mpc status | wc -l )" -gt 1 ] ||\
                 [ ! -f "$AU_DIR/AUDIO_LOOP_PID" ]; then
                QUERY=1
            fi
            ;;
        h)
            PLAY_ACTION=3
            if [ "$( mpc status | wc -l )" = 1 ] ||\
                 [ ! -f "$AU_DIR/AUDIO_LOOP_PID" ]; then
                QUERY=1
            fi
            ;;
        b)
            PLAY_ACTION=4
            if [ "$( mpc status | wc -l )" -gt 1 ] ||\
                 [ ! -f "$AU_DIR/AUDIO_LOOP_PID" ]; then
                QUERY=1
            fi
            ;;

        K)
            $MPC prev
            if [ ! -f "$AU_DIR/AUDIO_LOOP_PID" ]; then
                QUERY=1
            fi
            ;;
        J)
            $MPC next
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
        D)
            ACTION=4
            ;;
        '#')
            STATS=1
            ;;
        C)
            change_notify
            ;;
        k)
            if [ -f "$AU_DIR/AUDIO_LOOP_PID" ]; then
                change_notify
            fi
            kill "$(pgrep "$PROVIDER")" && echo "Killed $PROVIDER_NAME!"
            exit 0
            ;;
        Y)
            UPDATE=1
            ;;

        r)
            $MPC repeat
            ;;
        z)
            $MPC random
            ;;
        y)
            $MPC single
            ;;
        x)
            $MPC shuffle
            ;;
        c)
            $MPC clear
            ;;
        v)
            $MPC volume ${!ARGS_START}
            notify-send -a 'noxgrim:volume' -u low -h "int:value:$($MPC volume | grep -oP '\d+')"\
                "$PROVIDER_NAME volume " '%'
            ((ARGS_START++))
            ;;
        S)
            $MPC seek ${!ARGS_START}
            ((ARGS_START++))
            ;;

        a)
            ACTION=1
            ;;
        l)
            ACTION=2
            ;;
        d)
            ACTION=3
            ;;

        s)
            SEARCH_OPTION=1
            ;;
        f)
            SEARCH_OPTION=2
            ;;
        P)
            SEARCH_OPTION=3
            ;;
        L)
            SEARCH_OPTION=4
            ;;
        B)
            SEARCH_OPTION=5
            ;;

        *)
            echo "$C is not a valid command."
            echo 'Valid commands: abcdfhiklpqrstvxyzBCDJKLPQSY#'
            echo 'See -h for more info.'
            exit 1
    esac
done

# Non-stackable commands
if [ "$UPDATE" ]; then
    $MPC update --wait
    notify-send -u low 'Updated database.'
fi
case "$ACTION" in
    1) # Add
        case "$SEARCH_OPTION" in
            1) # Search
                RESULT="$( m_search "${@:$ARGS_START}" | filter )"
                if [ -n "$RESULT" ]; then
                    echo "$RESULT" | $MPC add
                else
                    notify-send -u low 'Nothing found.'
                fi
                ;;
            2) # Find
                RESULT="$( m_find "${@:$ARGS_START}" | filter )"
                if [ -n "$RESULT" ]; then
                    echo "$RESULT" | $MPC add
                else
                    notify-send -u low 'Nothing found.'
                fi
                ;;
            5) # Browse
                RESULT="$( m_browse "${@:$ARGS_START}" | filter )"
                if [ -n "$RESULT" ]; then
                    echo "$RESULT" | $MPC add
                fi
                ;;
            4) # Playlist
                pl_add   "${@:$ARGS_START}"
                ;;

            *) # Play or nothing
                $MPC add  "${@:$ARGS_START}"
        esac
        ;;
    2) # List
        case "$SEARCH_OPTION" in
            1) # Search
                m_search "${@:$ARGS_START}" | filter | clean_output
                ;;
            2) # Find
                m_find   "${@:$ARGS_START}" | filter | clean_output
                ;;
            5) # Browse
                m_browse "${@:$ARGS_START}" | filter | clean_output
                ;;
            4) # Playlist
                mpc lsplaylists
                ;;

            *) # Play or nothing
                $MPC playlist -f "$PLAYLIST_FORMAT" | clean_output
        esac
        ;;
    3) # Delete
        case "$SEARCH_OPTION" in
            1|2) # Search and find
                del_phrase "${@:$ARGS_START}" | $MPC del
                ;;
            5) # Browse
                pl_browse | $MPC del 2> /dev/null
                ;;
            3) # Play
                del_num "${*:$ARGS_START}" | $MPC del
                ;;
            4) # Playlist
                mpc rm "${*:$ARGS_START}"
        esac
        ;;
    4) # Execute
        mpc "${@:$ARGS_START}"
    ;;

    *)
        case "$SEARCH_OPTION" in
            3) # Play
                $MPC play "$( pos_matching "${@:$ARGS_START}" )" 2> /dev/null
                ;;
            5) # Browse
                play_all
                ;;
            4) # Playlist
                mpc save "${*:$ARGS_START}"
                ;;
        esac
esac
case "$PLAY_ACTION" in
    1)
        $MPC play
        ;;
    2)
        $MPC toggle
        ;;
    3)
        $MPC stop
        ;;
    4)
        $MPC pause
        ;;
esac
if [ "$INFORM" ]; then
    mpc status
fi
if [ "$STATS" ]; then
    mpc stats
fi
if [ -n "$QUERY" ] && [ ! -e "$AU_DIR/AUDIO_DO_NOT_QUERY" ] ||\
    [ "$QUERY" = 2 ]; then
    query_playing
fi

