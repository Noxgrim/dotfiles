#! /bin/bash

MPC='mpc -q'
AU_DIR='/tmp/audio_control/'
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
      fi
  fi
}
play_matching() {
    local SEARCH="$*"
    local NUM=1
    mpc playlist | clean_output |\
        while read TRACK; do
            if [ "$REGARD_CASE" ]; then
                if echo "$TRACK" | grep -qE "$SEARCH"; then
                    $MPC play "$NUM"
                    break
                fi
            else
                if echo "$TRACK" | grep -iqE "$SEARCH"; then
                    $MPC play "$NUM"
                    break
                fi
            fi
            ((NUM++))
        done
}
clean_output() {
    sed "s/%\(..\)/\\\\x\1/g" | xargs -0 printf 2> /dev/null
}
query_playing() {
    sleep 0.1 # Wait until mopidy updates its index
    if [ -z "$( mpc current )" ]; then
        notify-send -u low 'No track playing'
    elif [ -z "$( mpc -f '%title%' current )" ]; then
        CURRENT="$( mpc current | clean_output )"
        notify-send "<i>$( echo "$CURRENT" | sed -r 's/.*?\/(.*?)$/\1/' )</i>"\
            "$( echo "$CURRENT"  | sed -r 's/.*?:.*?:(.*?)\/.*?$/\1/')"
    else
        notify-send "$( mpc -f '%title%' current )" \
            "$( mpc -f '%artist% - %album%' current )"
    fi
}
change_notify() {
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
            if [[ "$( mpc current --wait 2>&1 >/dev/null )" ==\
                  *"Connection refused"* ]]; then
                notify-send -u critical 'Stopped change notifications!'\
                    "Mpc couldn't connect to Mopidy. Mopidy most likely died."
                killall mopidy 2> /dev/null
 \
      rm "$AU_DIR/AUDIO_LOOP_PID"
                break
            fi
            if [ ! -e "$AU_DIR/AUDIO_DO_NOT_QUERY" ]; then
                query_playing
            fi
        done
        ) & disown && echo $! > "$AU_DIR/AUDIO_LOOP_PID"
    fi
}

ARGS_START=1
AUTOSTART_MPD=1

if [ "$#" = 0 ]; then
    set -- "${@}" "t"; # Special case because most used; Reset to preserve behavior
fi

for ARG in "$@"; do
    if [[ "$ARG" =~ ^-.+$ ]]; then
        case "$ARG" in
            --no-autostart) ;&
            -n)
                AUTOSTART_MPD=0
                ((ARGS_START++))
                ;;
            --specify-type) ;&
            -s)
                SPECIFY_TYPE=1
                ((ARGS_START++))
                ;;
            -i) ;&
            --regard-case)
                REGARD_CASE=1
                ((ARGS_START++))
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
 be written in a string (e.g. LLp) with the arguments following after that.
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
  L mpc next
  H mpc prev
  Q Toggle the automatic displaying of a notification if the p, t, h, b, L, H
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
  P Search for track in the playlist by name and play it. Will be ignored
     when used with a or l.

 Handling:
  a Add results.
    Acts like 'mpc add [search results]' when used with s or f
    Acts like 'mpc add [args]'           when used alone
  l List results.
    Acts like 'echo [search results]'    when used with s or f
    Acts like 'mpc playlist'             when used alone

Options:
  -n  --no-autostart do not start mopidy automatically if it is not
                      running
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
    else
        break
    fi
done

if [ ! $( pgrep -f '/usr/sbin/mopidy' ) ]; then
    if [ "$AUTOSTART_MPD" ]; then
        mopidy &> "$AU_DIR/mopidy.log"&disown
        echo "Starting Mopidy!"
        [ ! "$NO_CHANGE_NOTIFY" ] && change_notify
        while [[ "$( mpc 2>&1 >/dev/null )" == *"Connection refused"* ]]; do
            sleep 0.5 ; done
    else
        echo 'Mopidy not running!'
        exit 1
    fi
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

        H)
            $MPC prev
            if [ ! -f "$AU_DIR/AUDIO_LOOP_PID" ]; then
                QUERY=1
            fi
            ;;
        L)
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
            killall mopidy && echo 'Killed Mopidy!'
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

        s)
            SEARCH_OPTION=1
            ;;
        f)
            SEARCH_OPTION=2
            ;;
        P)
            SEARCH_OPTION=3
            ;;

        *)
            echo "$C is not a valid command."
            echo 'Valid commands: pthbHLqQikCYrxzycvSalsfP'
            echo 'See -h for more info.'
            exit 1
    esac
done

# Non-stackable commands
if [ "$UPDATE" ]; then
    mpc update --wait
fi
case "$ACTION" in
    1)
        case "$SEARCH_OPTION" in
            1)
                m_search "${@:$ARGS_START}" | $MPC add
                ;;
            2)
                m_find   "${@:$ARGS_START}" | $MPC add
                ;;
            *)
                $MPC add  "${@:$ARGS_START}"
        esac
        ;;
    2)
        case "$SEARCH_OPTION" in
            1)
                m_search "${@:$ARGS_START}" |
                sed "s/%\(..\)/\\\\x\1/g"   | clean_output
                ;;
            2)
                m_find   "${@:$ARGS_START}" |
                sed "s/%\(..\)/\\\\x\1/g"   | clean_output
                ;;
            *)
                $MPC playlist | clean_output
        esac
        ;;
    *)
        case "$SEARCH_OPTION" in
            3)
                play_matching "${@:$ARGS_START}"
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

