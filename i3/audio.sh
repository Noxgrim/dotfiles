#! /bin/bash

MPC='mpc -q'
AU_DIR='/tmp/audio_control'
TARGET='Mpd'
MPD_CONF="$HOME/.mpdconf"
MUSIC_DIR="$(grep 'music_directory' "$MPD_CONF" | grep -oP '(?<=").*?(?=")' |\
    sed -r "s/~/$( sed 's/[&/\]/\\&/g' <<<"$HOME"  )/" )"
ICON_RES='80:80' #Only affects newly created icons
RADIO_QUERY_RES=5

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
        while read TRACK; do
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
      mpc lsplaylists |\
          while read LIST; do
            if echo "$LIST" | grep -"$IGNORE_CASE"qP "$SEARCH"; then
                $MPC load "$LIST" > /dev/null
                unset LIST
                break
            fi
        done
        if [ -n "$LIST" ]; then
            echo "No matching playlist found!"
        fi
  fi
}
del_num() {
    echo "$( echo "$*" | sed 's/\./0/g' |\
       sed "s/\\$/$( mpc playlist | wc -l )/g" )"
}
del_phrase() {
    local OUT=""
    for ARG in $@; do
        local RES=""
        while read TERM; do
            if echo "$TERM" | grep -qP '^\\(?!\\)'; then
                TERM=$(echo "$TERM" | sed -r 's/^\\//')
                RESULT=$( del_num "$TERM" )
            else
                TERM=$(echo "$TERM" | sed -r 's/^\\\\/\\/')
                RESULT="$( pos_matching "$TERM" )"
            fi
            if [ -z "$RESULT" ]; then
                RES="$RES?-"
            else
                RES="$RES$RESULT-"
            fi
        done < <( echo "$ARG" | grep -oE '(\\-|[^-])*?' | sed 's/\\-/-/g' |\
                  head -n 2 )
        # Use 'process substitution' to access variable
        # outside of loop
        OUT="$OUT${RES:0:-1} "
    done
    echo "${OUT:0:-1}"
}
clean_output() {
    sed "s/%\(..\)/\\\\x\1/g" | xargs -0 printf 2> /dev/null
}
query_playing() {
    sleep 0.1 # Wait until mopidy or mpd update their indices
    if [ -z "$( mpc current )" ]; then
        notify-send -u low 'No track playing'
    elif [ -z "$( mpc -f '%time%' current )" ]; then # Most probably a radio station
        notify-send "$( mpc -f '%title%' current )"\
            "$( mpc -f '%name%' current )"
    else
        local CURRENT="$( mpc -f "%file%" current | clean_output )"
        local DIR="$( dirname "$CURRENT" )"
        local ICON_ARG=()
        check_icon "$MUSIC_DIR/$DIR"
        if [ -f "$MUSIC_DIR/$DIR/.cover_mpd.png" ]; then
            ICON_ARG=( '-i' "$MUSIC_DIR/$DIR/.cover_mpd.png" )
        else
            ICON_ARG=( '--' )
        fi
        if [ -z "$( mpc -f '%title%' current )" ]; then
            notify-send "<i>$( basename "$CURRENT" '.mp3'  )</i>"\
                "$DIR" "${ICON_ARG[@]}"
        else
            notify-send "$( mpc -f '%title%' current )"\
                "$( mpc -f '[[%artist% • ][%album%]|[<i>Unknown</i>]]|[<i>Unknown</i>]' current )" "${ICON_ARG[@]}"
        fi
    fi
}
check_icon() {
    (
        cd "$1"
        local FILES=
        shopt -s nullglob
        if [ -f ".cover_mpd.png" -o -f ".no_cover_found" ]; then
            return
        elif [ -f cover.png -o -f cover.jpg -o -f cover.jpeg ]; then
            FILES=( cover.png* cover.jpg* cover.jpeg* )
        else
            FILES=( *.mp3 )
        fi
        if ! ffmpeg -i "${FILES[0]}" -vf scale="$ICON_RES" ".cover_mpd.png" &> /dev/null; then
            touch ".no_cover_found"
        fi
    )
}
change_notify() {
    local LAST=
    if [ -f "$AU_DIR/AUDIO_LOOP_PID" ]; then
        cat "$AU_DIR/AUDIO_LOOP_PID" | xargs kill -SIGKILL
        echo 'Stopped change notifications!'
        rm "$AU_DIR/AUDIO_LOOP_PID"
    else
        (
        while [[ "$( mpc 2>&1 >/dev/null )" == *"Connection refused"* ]]; do
            sleep 0.5; done
        echo 'Started change notifications!'

        while true; do
            if [ -z "$( mpc -f '%time%' current )" ]; then #Stream
                sleep "$RADIO_QUERY_RES"
                if [ ! -e "$AU_DIR/AUDIO_DO_NOT_QUERY" -a\
                     "$( mpc -f '%title%' current )" != "$LAST" ]; then
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
                notify-send -u critical 'Stopped change notifications!'\
                    "Mpc couldn't connect to $TARGET. $TARGET most likely died."
                killall mopidy 2> /dev/null
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
    set -- "${@}" "t"; # Special case because most used; Reset to preserve behavior
fi

for ARG in "$@"; do
    if [[ "$ARG" =~ ^-.+$ ]]; then
        case "$ARG" in
            --no-autostart) ;&
            -n)
                AUTOSTART=0
                ;;
            -m) ;&
            --mopidy)
                MOPIDY=1
                TARGET='Mopidy'
                ;;
            --specify-type) ;&
            -s)
                SPECIFY_TYPE=1
                ;;
            -i) ;&
            --regard-case)
                IGNORE_CASE=""
                ;;
            -U) ;&
            --no-unique)
                NO_UNIQUE=1
                ;;
            --no-change-notifications) ;&
            -c)
                NO_CHANGE_NOTIFY=1
                ;;
            --help) ;&
            -h)
                echo "$0 Help
A simple wrapper script that makes the use of mopidy and mpc easier
and allows multitasking.
$0 [OPTION]... COMMANDS

Commands:
 Commands control what tasks the script performs. Multiple commands must
 be written in a string (e.g. JJp) with the arguments following after that.
 The arguments will be associated with the commands that accessed them
 accordingly. The search query commands (s, f) will always accept the
 remaining arguments.

 Non-stackable: (Last will be executed if mutually exclusive;
                 Last to be executed)
  p mpc play
  t mpc toggle
  h mpc stop
  P mpc pause
  q Display a notification with the current title, artist and album; will
     also be displayed if automatic notifications are disabled
  i mpc status
  k killall mopidy (executed immediately)
  Y mpc update --wait

 Stackable:
  K mpc next
  J mpc prev
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

 Searching: (Must be used with a handle command; Last will be executed)
  s mpc search
  f mpc find
  P Search for track in the playlist by name and play it. To reference the N-th
     occurrence use 'N:<search term>'. Will be ignored when used with a or l.
  L Reference a playlists.

 Handling:
  a Add results.
    Acts like 'mpc add [search results]' when used with s or f
    Acts like 'mpc load [pl name]'       when used with L
    Acts like 'mpc add [args]'           when used alone or with P
  l List results.
    Acts like 'echo [search results]'    when used with s or f
    Acts like 'mpc lsplaylists'          when used with L
    Acts like 'mpc playlist'             when used alone or with P
  d Delete results
    Acts like 'mpc del [args]'           when used with P
     Special values: $  last playlist element
                     .  current playlist element
    Behaviour                            when used with s or f
     Search for each text occurrence of elements (may be separated by '-' to
      indicate a range). The syntax of 'play matching track P' is used. To
      behave like 'delete by number P' the element can be preceded by a '\\'.
      Example:
        roses-violets forget\\-me\\-not-\\$
    Acts like 'mpc rm \"[args]\"'        when used with L

  - (No handling operator)
    Plays matching song                  when P
    Acts like 'mpc save [new pl name]'   when L

Options:
  -n  --no-autostart do not start mpd or mopidy automatically if they are not
                      running
  -m  --mopidy       start mopidy instead of mpd
  -c  --no-change-notifications
                     Do not automatically activate the change notifications.
                      Can be reactivated every time with the C command.
  -s, --specify-type Specify the type of search queries yourself.
                      The type is set to 'any' if this parameter is
                      omitted and all subsequent arguments will be
                      joined into a single query.
                      Possible types are:
                       album     any       artist    comment   composer
                       date      disc      filename  genre     name
                       performer title     track
  -I, --regard-case  do not ignore case when searching with 'P'
  -U, --no-unique    also add titles if they are already in the current
                      playlist
  -h, --help         display this help and exit
  --                 stop arguments

Note: if neither options nor commands are specified the script will execute
      't'.
"
                exit 0
                ;;
            --)
                ((ARGS_START++))
                break 2
                ;;
        esac
        ((ARGS_START++))
    else
        break
    fi
done

if [ "$MOPIDY" ]; then
    if [ ! $( pgrep -f '/usr/sbin/mopidy' ) ]; then
        if [ "$AUTOSTART" ]; then
            mopidy &> "$AU_DIR/mopidy.log"&disown
            echo "Starting $TARGET!"
            [ ! "$NO_CHANGE_NOTIFY" ] && change_notify
            while [[ "$( mpc 2>&1 >/dev/null )" == *"Connection refused"* ]]; do
                sleep 0.5 ; done
        else
            echo "$TARGET not running!"
            exit 1
        fi
    fi
else
    if [ ! $( pgrep -f '/usr/bin/mpd' ) ]; then
        if [ "$AUTOSTART" ]; then
            mpd "$HOME/.mpdconf"
            echo "Starting $TARGET!"
            while [[ "$( mpc 2>&1 >/dev/null )" == *"Connection refused"* ]]; do
                sleep 0.5 ; done
        else
            echo "$TARGET not running!"
            exit 1
        fi
    fi
fi
if [ ! "$NO_CHANGE_NOTIFY" -a ! -f "$AU_DIR/ATTEMPTED_LOOP" ]; then
    change_notify
fi
if [ ! -f "$AU_DIR/ATTEMPTED_LOOP" ]; then
    touch "$AU_DIR/ATTEMPTED_LOOP"
fi

COMMAND="${!ARGS_START}"
((ARGS_START++))
for C in $( echo $COMMAND | grep -o . ); do
    case "$C" in
        p)
            PLAY_ACTION=1
            if [ "$( mpc status | wc -l )" -gt 1 -o\
                 ! -f "$AU_DIR/AUDIO_LOOP_PID" ]; then
                QUERY=1
            fi
            ;;
        t)
            PLAY_ACTION=2
            if [ "$( mpc status | wc -l )" -gt 1 -o\
                 ! -f "$AU_DIR/AUDIO_LOOP_PID" ]; then
                QUERY=1
            fi
            ;;
        h)
            PLAY_ACTION=3
            if [ "$( mpc status | wc -l )" = 1 -o\
                 ! -f "$AU_DIR/AUDIO_LOOP_PID" ]; then
                QUERY=1
            fi
            ;;
        b)
            PLAY_ACTION=4
            if [ "$( mpc status | wc -l )" -gt 1 -o\
                 ! -f "$AU_DIR/AUDIO_LOOP_PID" ]; then
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
        C)
            change_notify
            ;;
        k)
            if [ -f "$AU_DIR/AUDIO_LOOP_PID" ]; then
                change_notify
            fi
            killall mopidy && echo "Killed $TARGET!"
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

        *)
            echo "$C is not a valid command."
            echo 'Valid commands: abcfhiklpqrstvxyzCJKLPQSY'
            echo 'See -h for more info.'
            exit 1
    esac
done

# Non-stackable commands
if [ "$UPDATE" ]; then
    mpc update --wait
fi
case "$ACTION" in
    1) # Add
        case "$SEARCH_OPTION" in
            1)
                m_search "${@:$ARGS_START}" | filter | $MPC add
                ;;
            2)
                m_find   "${@:$ARGS_START}" | filter | $MPC add
                ;;
            4)
                pl_add   "${@:$ARGS_START}"
                ;;

            *)
                $MPC add  "${@:$ARGS_START}"
        esac
        ;;
    2) # List
        case "$SEARCH_OPTION" in
            1)
                m_search "${@:$ARGS_START}" | filter | clean_output
                ;;
            2)
                m_find   "${@:$ARGS_START}" | filter | clean_output
                ;;
            4)
                mpc lsplaylists
                ;;

            *)
                $MPC playlist -f '%position%. %artist% • %title%' | clean_output
        esac
        ;;
    3) # Delete
        case "$SEARCH_OPTION" in
            1)
                ;&
            2)
                del_phrase "${*:$ARGS_START}" | $MPC del
                ;;
            3)
                del_num "${*:$ARGS_START}" | $MPC del
                ;;
            4)
                mpc rm "${*:$ARGS_START}"
        esac
        ;;

    *)
        case "$SEARCH_OPTION" in
            3)
                $MPC play "$( pos_matching "${@:$ARGS_START}" )" 2> /dev/null
                ;;
            4)
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
if [ -n "$QUERY" -a ! -e "$AU_DIR/AUDIO_DO_NOT_QUERY"\
     -o "$QUERY" = 2 ]; then
    query_playing
fi

