#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

[ "$(id -u)" != 0 ] && echo 'Needs superuser!' >&2 && return 1

USER="$(getent passwd 1000 | cut -d: -f1)"
HOME="$(getent passwd 1000 | cut -d: -f6)"
DIR="/tmp/$USER/"
[ -d "$DIR" ] || su "$USER" -c "mkdir -p '$DIR'"
FIFO="$DIR/service"
WORKING="$DIR/service.working"


service() {
  [ -p "$FIFO" ] || mkfifo "$FIFO"
  chmod 622 "$FIFO"
  LAST='0'
  while [ -p "$FIFO" ]; do
    read -r CMD < "$FIFO"
    echo "Executing $CMD"
    DIFF=$(($(date +%s)-LAST))
    case "$CMD" in
      'brightness reload')
        if [ "$DIFF" -lt 120 ]; then
          echo "Refusing to serve after only $DIFF seconds!" >&2
        elif [ -x '/root/brightness.sh'  ]; then
          touch "$WORKING"
          sleep 5 # wait for monitors to wake uo I guess
          '/root/brightness.sh' reload || true
          rm -f "$WORKING"
          LAST="$(date +%s)"
        fi
        ;;
      trigger_backup)
        if [ "$DIFF" -lt 600 ]; then
          echo "Refusing to serve after only $DIFF seconds!" >&2
        elif [ -f '/etc/systemd/system/backup.service' ]; then
          touch "$WORKING"
          systemctl start backup.service
          rm -f "$WORKING"
          LAST="$(date +%s)"
        fi
        ;;
      'reset_usb '*)
        if [ "$DIFF" -lt 20 ]; then
          echo "Refusing to serve after only $DIFF seconds!" >&2
        else
          touch "$WORKING"
          IFS=' ' read -r -a ARGS <<< "$CMD"
          for ARG in "${ARGS[@]:1}"; do
            F="/sys/bus/usb/devices/$ARG/authorized"
            if [ -e "$F" ]; then
              echo 0 > "$F"
              sleep 0.1
              echo 1 > "$F"
            fi
          done
          rm -f "$WORKING"
          LAST="$(date +%s)"
        fi
        ;;
      *)
        echo "Unknown command: $CMD" >&2
        ;;
    esac
  done
}

clean() {
  trap - SIGINT SIGTERM
  [ -p "$FIFO" ] && rm "$FIFO"
  setsid ps -s $$ -o pid= | grep -v ^$$\$ | xargs -r kill 2>/dev/null || true
}

service

trap clean SIGINT SIGTERM
