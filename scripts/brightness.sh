#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
if [ "$(id -u)" == 0 ]; then
  USER="$(getent passwd 1000 | cut -d: -f1)"
  HOME="$(getent passwd 1000 | cut -d: -f6)"
  DIR="/tmp/$USER/brightness"
  CACHE="$HOME/.cache/brightness.devs"
  [ -d "$DIR" ] || su "$USER" -c "mkdir -p '$DIR'"
  [ -d "${CACHE%/*}" ] || su "$USER" -c "mkdir -p '${CACHE%/*}'"
else
  DIR="/tmp/$USER/brightness"
  CACHE="$HOME/.cache/brightness.devs"
  [ -d "$DIR" ] || mkdir -p "$DIR"
  [ -d "${CACHE%/*}" ] || mkdir -p "${CACHE%/*}"
fi
REPORT=false


setup() {
  [ "$(id -u)" != 0 ] && echo 'Needs superuser!' >&2 && return 1
  source '/root/notify.sh'

  modprobe -r ddcci_backlight ddcci
  modprobe i2c-dev
  ddcutil detect -t | sed '/\/dev/{s,.*/i2c-\([0-9]*\),\1@i2c-\1,;:a;{N;/\n\s*Monitor/be;s/\n.*//;ba};:e;s/\n[^:]*:\s*\([^:*]*:[^:]*\).*/@\1/;b};d' > "$DIR/data"
  while IFS=@ read -r _ DEV _; do
    echo 'ddcci 0x37' > "/sys/bus/i2c/devices/$DEV/new_device" 2>/dev/null || true
  done < "$DIR/data"
  modprobe -r i2c-dev
  modprobe ddcci ddcci_backlight
  sleep 1

  while IFS=@ read -r ID _ NAME; do
    {
      if [ ! -f "$CACHE" ] || ! grep -Fo "$NAME" "$CACHE"; then
        local DEV
        if [ -e "/sys/class/backlight/ddcci$ID" ]; then
          DEV="ddcci$ID"
        else
          DEV="$(find '/sys/class/backlight' -follow -maxdepth 3 -iname 'i2c-'"$ID" -print -quit 2>/dev/null || true)"
          if [ -n "$DEV" ]; then
            DEV=${DEV#/sys/class/backlight/}
            DEV=${DEV%/}
            DEV=${DEV%%/*}
          else
            exit
          fi
        fi

        if [ -e "/sys/class/backlight/$DEV" ]; then
          notify "Testing speed of minitor ${NAME:-$DEV}" "This may take a while." &>/dev/null
          local OLD TIME
          OLD="$(xbacklight -ctrl "$DEV" -getf)"
          xbacklight -ctrl "$DEV" -set 100
          TIME="$(date +%s%N)"
          xbacklight -ctrl "$DEV" -set 1 -time 1 -step 1000
          TIME="$((($(date +%s%N)-TIME)/1000000))"
          TIME_STEP="$((TIME/1000))"
          xbacklight -ctrl "$DEV" -set "$OLD"
          echo "$TIME_STEP $NAME"
          notify "Minitor  ${NAME:-$DEV} tested" "Takes ${TIME_STEP}ms/step" &>/dev/null
        fi
      fi
    }&
  done < "$DIR/data" >> "${CACHE}_new"
  wait
  if [ -f "${CACHE}_new" ]; then
    cat "${CACHE}_new" >> "$CACHE"
    rm "${CACHE}_new"
  fi
  chown 1000:1000 "$CACHE"
}

_set() {
  : $((USED++))
  [ -n "${3+x}" ] && : $((USED++))
  [ -n "${4+x}" ] && : $((USED++))
  local OP="$1" TARGET="$2" TIME="${3-0}"
  local STEPS="${4-$((TIME/50))}"
  shopt -s nullglob extglob
  [ -f "$DIR/PID" ] && kill "$(cat "$DIR/PID")" || true
  echo "$$" > "$DIR/PID"
  for DEV in /sys/class/backlight/*; do
    DEV="${DEV##*/}"
    (
      case "$DEV" in
        ddcci*)
          NO="${DEV##*([^0-9])}"
          ;;
        *)
          NO="$(find "/sys/class/backlight/$DEV/" -follow -maxdepth 2 -iname 'i2c-*' -printf '%f' -quit 2>/dev/null||true)"
          NO="${NO##*([^-])-}"
          ;;
      esac
      if [ -z "$NO" ]; then
        echo "Couldn't find number for device $DEV!"
        TIME_STEP=0
      else
        TIME_STEP="$(grep -m1 " $(grep "^$NO@" "$DIR/data" | cut -d@ -f3-)$" "$CACHE" | cut -d\  -f1)"
      fi
      if [ "$((STEPS*TIME_STEP))" -gt "$TIME" ]; then
        STEPS=$((TIME/TIME_STEP))
      fi
      if [ "$OP" = restore ]; then
        TARGET="$(grep "^$DEV@" "$DIR/save" | cut -d@ -f2)"
        OP='set'
      fi
      xbacklight -ctrl "$DEV" -"$OP" "$TARGET" -time "$((TIME-(STEPS*TIME_STEP)))" -steps "$STEPS"
    )&
  done
  wait
  rm "$DIR/PID"
  shopt -u nullglob extglob
}

_get() {
  shopt -s nullglob
  for DEV in /sys/class/backlight/*; do
    DEV="${DEV##*/}"
    echo "$DEV@$(xbacklight -ctrl "$DEV" -"$1")"&
  done
  wait
  shopt -u nullglob
}

clean() {
  trap - SIGINT SIGTERM
  [ -f "$DIR/PID" ] && rm "$DIR/PID"
  TOTAL=$((TOTAL+USED))
  $REPORT && echo "$TOTAL" >&2
  [ -f "$DIR/PID" ] && rm "$DIR/PID"
  setsid ps -s $$ -o pid= | grep -v ^$$\$ | xargs -r kill 2>/dev/null || true
}

trap clean SIGINT SIGTERM

TOTAL=0
while [ $# -gt 0 ]; do
  USED=0
  TOTAL=$((TOTAL+1))
  ARG="$1"
  shift
  case "$ARG" in
    report)
      REPORT=true
      TOTAL=$((TOTAL-1))
      ;;
    init|reload)
      setup
      ;;
    save)
      _get getf > "$DIR/save"
      ;;
    get|getf|get-steps)
      _get "$ARG"
      ;;
    kill)
      [ -f "$DIR/PID" ] && kill "$(cat "$DIR/PID")" || true
      ;;
    set|inc|dec)
      _set "$ARG" "$@"
      TOTAL=$((TOTAL+USED))
      shift "$USED"
      ;;
    restore)
      [ ! -f  "$DIR/save" ] && echo 'Nothing to restore!' >&2 && break
      _set restore 'x' "$@"
      USED=$((USED-1))
      TOTAL=$((TOTAL+USED))
      shift "$USED"
      ;;
    reset)
      USED=$((USED-1))
      _set set '100' "$@"
      TOTAL=$((TOTAL+USED))
      shift "$USED"
      ;;
    help)
      cat << EOF
set VALUE [TIME [STPES]]:
        set all devices to value
inc VALUE [TIME [STPES]]:
        increase all devices by value
dec VALUE [TIME [STPES]]:
        deccrease all devices by value
reset:  short for 'set 100'
save:   save current state
restore [TIME [STPES]]:
        restore previous state
kill:   kill backlight change in progress
[as root] init|reload:
        setup relevant files,
[debug] report:
        print number of arguments consumed to stderr
        (excluding this one)
EOF
      exit
      ;;
    *)
      break
  esac
done
$REPORT && echo "$TOTAL" >&2
