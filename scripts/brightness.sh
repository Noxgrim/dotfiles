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
  ddcutil detect -t | sed '/\/dev/{s,.*/i2c-\([0-9]*\),\1@i2c-\1,;:a;{N;/\n\s*Monitor/be;s/\n.*//;ba};:e;s/\n[^:]*:\s*\([^:*]*:[^:]*:.*\)/@\1/;b};d' > "$DIR/data"
  cp "$DIR/data" "$DIR/selected"
  chown "$USER:$USER" "$DIR/selected"
  while IFS=@ read -r _ DEV _; do
    echo 'ddcci 0x37' > "/sys/bus/i2c/devices/$DEV/new_device" 2>/dev/null || true
  done < "$DIR/data"
  modprobe -r i2c-dev
  modprobe ddcci ddcci_backlight
  sleep 1

  while IFS=@ read -r ID _ NAME; do
    {
      if [ ! -f "$CACHE" ] || ! grep -Fo "$NAME" "$CACHE" &>/dev/null; then
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
  chown "$USER:$USER" "$CACHE"
}

_select() {
  source "$HOME/.device_specific/monitor_names.sh"
  local INPUT
  INPUT="$(
    local -i LINE_NO=0
    while IFS=@ read -r NO DEV ID; do
    ((LINE_NO++))
    local MNO="${ID_MHDL["$ID"]-'?'}" SEL=0
    if grep '^[^@]*@[^@]*@'"$ID" "$DIR/selected" -q; then
      SEL=1
    fi
    printf '%s\t%s\t(%s)\t%s\n' "$MNO" "$SEL" "$ID" "$LINE_NO"
  done < "$DIR/data")"
  if [ $# = 0 ]; then
    sed "$(sort -n <<< "$INPUT" | rofi 2>/dev/null -dmenu -multi-select -no-custom -p 'Brightness control: ' -display-columns 1,3 \
      -a "$(sort -n <<< "$INPUT" | cut -f2 | grep 1 -n | cut -d: -f1 | while read -r I; do echo "$((I-1))"; done | tr '\n' ,)" | \
      cut -f4 | tr '\n' ';' | sed 's/;/p;/g')" "$DIR/data" -n > "$DIR/selected"
  else
    USED="$#"
    sed "$(cut -f1,4 <<< "$INPUT" | grep -E "^($(printf '|%s' "$@" | cut -c2-))"$'\t' | cut -f2 | tr '\n' ';' | sed 's/;/p;/g')" \
      "$DIR/data" -n > "$DIR/selected"
  fi
}

find_no() {
  shopt -s nullglob extglob
  local NO=
  case "$DEV" in
    ddcci*)
      NO="${DEV##*([^0-9])}"
      ;;
    *)
      NO="$(find "/sys/class/backlight/$DEV/" -follow -maxdepth 2 -iname 'i2c-*' -printf '%f' -quit 2>/dev/null||true)"
      NO="${NO##*([^-])-}"
      ;;
  esac
  echo "$NO"
}

_notify() {
  if [ "$(id -u)" == 0 ]; then
    source '/root/notify.sh'
  else
    source "$SCRIPT_ROOT/scripts/notify.sh"
  fi
  local DATA BOT NEW
  DATA="$(_get true get)"
  if [ -z "$DATA" ]; then
    notify -a 'noxgrim:brightness' -u low 'No brightness devices' '!' >/dev/null
    return
  fi
  BOT="$(sort -nut@ -k2,2 <<< "$DATA")"
  NEW="$(head -n 1 <<< "$BOT" | cut -d@ -f2)"
  if [ "$(wc -l <<< "$BOT")" = 1 ]; then
    notify -a 'noxgrim:brightness' -u low -h "int:value:$NEW" 'Brightness ' '%' >/dev/null
  else
    notify -a 'noxgrim:brightness' -u low -h "int:value:$NEW" 'Brightness ' '%'$'\n'"<i>$(
      source "$HOME/.device_specific/monitor_names.sh"
      shopt -s extglob
      while IFS=@ read -r DEV VAL; do
        NAME="${ID_MHDL["$(grep "^$(find_no "$DEV")@" "$DIR/data" | cut -d@ -f3-)"]-"$DEV"}"
        echo "$NAME: $VAL%"
      done <<< "$DATA" | sort -n
    )</i>" >/dev/null
  fi
}


_set() {
  : $((USED++))
  [ -n "${3+x}" ] && : $((USED++))
  [ -n "${4+x}" ] && : $((USED++))
  local OP="$1" TARGET="$2" TIME="${3:-0}"
  local STEPS="${4:-$((TIME/50))}"
  shopt -s nullglob extglob
  [ -f "$DIR/PID" ] && kill "$(cat "$DIR/PID")" || true
  echo "$$" > "$DIR/PID"
  for DEV in /sys/class/backlight/*; do
    DEV="${DEV##*/}"
    (
      NO="$(find_no "$DEV")"
      if [ -z "$NO" ]; then
        echo "Couldn't find number for device $DEV!"
        TIME_STEP=0
      else
        grep "^$NO@" "$DIR/selected" -q &> /dev/null || exit
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
  [ -f "$DIR/PID" ] && rm "$DIR/PID"
  shopt -u nullglob extglob
}

_get() {
  shopt -s nullglob
  for DEV in /sys/class/backlight/*; do
    DEV="${DEV##*/}"
    local NO="$(find_no "$DEV")"
    if "$1" && [ -n "$NO" ] && ! grep "^$NO@" "$DIR/selected" -q &> /dev/null; then
      continue
    fi
    echo "$DEV@$(xbacklight -ctrl "$DEV" -"$2")"&
  done
  wait
  shopt -u nullglob
}

clean() {
  trap - SIGINT SIGTERM
  [ -f "$DIR/PID" ] && rm "$DIR/PID"
  TOTAL=$((TOTAL+USED))
  $REPORT && echo "$TOTAL" >&2
  setsid ps -s $$ -o pid= | grep -v ^$$\$ | xargs -r kill 2>/dev/null || true
}

trap clean EXIT

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
    notify)
      _notify
      ;;
    init|reload)
      setup
      ;;
    save)
      _get false getf > "$DIR/save"
      ;;
    get|getf|get-steps)
      _get true "$ARG"
      ;;
    get-all|getf-all|get-steps-all)
      _get false "${ARG%-all}"
      ;;
    kill)
      [ -f "$DIR/PID" ] && kill "$(cat "$DIR/PID")" || true
      ;;
    select|enable)
      _select "$@"
      TOTAL=$((TOTAL+USED))
      shift "$USED"
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
        set all enabled devices to value
inc VALUE [TIME [STPES]]:
        increase all enabled devices by value
dec VALUE [TIME [STPES]]:
        decrease all enabled devices by value
reset: [TIME [STPES]] short for 'set 100 TIME STEPS'
save:   save current state
restore [TIME [STPES]]:
        restore previous state of enabled devices
select [MHDL…]:
        enable monitos with given handle for brightness control
        and disable others
        if no arguments are given, let users decide interactively
        with rofi
kill:   kill backlight change in progress
notify: send a notification about the current brightness
[as root] init|reload:
        setup relevant files
[debug] report:
        print number of arguments consumed to stderr
        (excluding this one)
[debug] get|getf|get-steps:
        return the values of all enabled devices as percent, fraction
        and total supported steps respectively
[debug] get-all|getf-all|get-steps-all:
        same as get* but include all devices, also disabled ones
EOF
      exit
      ;;
    *)
      break
  esac
  USED=0
done
