#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

[ "$(id -u)" != 0 ] && echo 'Needs superuser!' >&2 && return 1

USER="$(getent passwd 1000 | cut -d: -f1)"
HOME="$(getent passwd 1000 | cut -d: -f6)"
DIR="/tmp/$USER/"
[ -d "$DIR" ] || su "$USER" -c "mkdir -p '$DIR'"
FIFO="$DIR/service"


service() {
  [ -p "$FIFO" ] || mkfifo "$FIFO"
  chmod 622 "$FIFO"
  LAST='0'
  while [ -p "$FIFO" ]; do
    read -r CMD < "$FIFO"
    echo "Executing $CMD"
    case "$CMD" in
      'brightness reload')
        DIFF=$(($(date +%s)-LAST))
        if [ "$DIFF" -lt 120 ]; then
          echo "Refusing to serve after only $DIFF seconds!" >&2
        elif [ -x '/root/brightness.sh'  ]; then
          '/root/brightness.sh' reload || true
          LAST="$(date +%s)"
        fi
        ;;
      trigger_backup)
        DIFF=$(($(date +%s)-LAST))
        if [ "$DIFF" -lt 600 ]; then
          echo "Refusing to serve after only $DIFF seconds!" >&2
        elif [ -f '/etc/systemd/system/backup.service' ]; then
          systemctl start backup.service
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
