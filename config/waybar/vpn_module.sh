#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# shellcheck disable=SC1091
source "$SCRIPT_ROOT/data/shared/local_env.sh"


SYM_CON='  '
SYM_PRO='    '
SYM_PAU='    '
SYM_DIS='    '
SYM_ERR='    '
SYM_UNK='    '

HAS_MULLVAD="$(command -v mullvad &>/dev/null && echo true || echo false)"
HAS_OPENVPN="$(command -v openvpn3 &>/dev/null && [ -n "${OPENVPN_CONFIG-}" ] && echo true || echo false)"


mullvad_status() {
  while [ "$(ps -o ppid= $$)" != 1 ]; do
    # loop as long as we are not reparented because waybar was restarted
    mullvad status -j listen | while read -r INFO; do
      eval "$(jq -r '"STATE=\"\(.state)\"\n
                      COUNTRY=\"\(.details?.location?.country?)\"\n
                      CITY=\"\(.details?.location?.city?)\""' <<< "$INFO")"
      case "$STATE" in
        connected)
          printf '{"text": "%s", "tooltip": "%s"}\n' "$SYM_CON" 'Mullvad: '"$COUNTRY ($CITY)"
          ;;
        disconnected)
          printf '{"text": "%s", "tooltip": "%s"}\n' "$SYM_DIS" "No VPN"
          ;;
        disconnecting|connecting)
          printf '{"text": "%s", "tooltip": "%s"}\n' "$SYM_PRO" "Mullvad: $STATE"
          ;;
        *)
          printf '{"text": "%s", "tooltip": "%s"}\n' "$SYM_UNK" "Mullvad: $STATE"
          ;;
      esac
    done || true
  done
}
mullvad_toggle() {
  case "$(mullvad status -j | jq -r .state)" in
    connected)
      mullvad disconnect
      ;;
    disconnected)
      mullvad connect
      ;;
  esac
}
mullvad_kill() {
  pkill -f 'mullvad status -j listen' || true
}

openvpn_status() {
  STATUS="$(openvpn3 sessions-list)"
  if grep '[Cc]onfig name: '"$OPENVPN_CONFIG" -q <<< "$STATUS"; then
    STATUS="$(grep '[Cc]onfig name: '"$OPENVPN_CONFIG" <<< "$STATUS" -A2 | tail -n1 | cut -d: -f2-)"
    case "${STATUS,,}" in
      *'client connected'*)
        printf '{"text": "%s", "tooltip": "%s"}\n' "$SYM_CON"  "OpenVPN: $OPENVPN_CONFIG"
        ;;
      *)
        printf '{"text": "%s", "tooltip": "%s"}\n' "$SYM_UNK"  "OpenVPN: $STATUS ($OPENVPN_CONFIG)"
    esac
  else
    printf '{"text": "%s", "tooltip": "%s"}\n' "$SYM_DIS" "No VPN"
  fi
  while [ "$(ps -o ppid= $$)" != 1 ]; do
    # loop as long as we are not reparented because waybar was restarted

    # we have to read it like that because otherwise noting is read util EOF :shrug:
    openvpn3 log -c "$OPENVPN_CONFIG" |\
      while read -r LINE; do
        STATUS="$(sed -n 's/^[^[]*.status] //p' <<< "${LINE,,}")"
        case "$STATUS" in
          '');; # no status
          'connection, client connecting'|'connection, configuration ok:'*)
            printf '{"text": "%s", "tooltip": "%s"}\n' "$SYM_PRO" "OpenVPN: connecting… ($OPENVPN_CONFIG)"
            ;;
          'connection, client reconnect')
            printf '{"text": "%s", "tooltip": "%s"}\n' "$SYM_PRO" "OpenVPN: reconnecting… ($OPENVPN_CONFIG)"
            ;;
          'connection, client disconnecting')
            printf '{"text": "%s", "tooltip": "%s"}\n' "$SYM_PRO" "OpenVPN: disconnecting… ($OPENVPN_CONFIG)"
            ;;
          'session, url authentication:'*)
            printf '{"text": "%s", "tooltip": "%s"}\n' "$SYM_PRO" "OpenVPN: authenticating in browser… ($OPENVPN_CONFIG)"
            ;;
          'connection, client pausing connection:'*)
            printf '{"text": "%s", "tooltip": "%s"}\n' "$SYM_PRO" "OpenVPN: pausing… ($OPENVPN_CONFIG)"
            ;;
          'connection, client connection resuming')
            printf '{"text": "%s", "tooltip": "%s"}\n' "$SYM_PRO" "OpenVPN: resuming… ($OPENVPN_CONFIG)"
            ;;
          'connection, client connection paused')
            printf '{"text": "%s", "tooltip": "%s"}\n' "$SYM_PAU" "OpenVPN: paused ($OPENVPN_CONFIG)"
            ;;
          'connection, client connected')
            printf '{"text": "%s", "tooltip": "%s"}\n' "$SYM_CON"  "OpenVPN: $OPENVPN_CONFIG"
            ;;
          'connection, client disconnected'|'connection, client process exited')
            printf '{"text": "%s", "tooltip": "%s"}\n' "$SYM_DIS"  "OpenVPN: disconnected ($OPENVPN_CONFIG)"
            ;;
          'connection, client authentication failed:'*)
            MESSAGE="${STATUS#*: }"
            printf '{"text": "%s", "tooltip": "%s"}\n' "$SYM_ERR"  "OpenVPN: $MESSAGE ($OPENVPN_CONFIG)"
            # shellcheck disable=SC1091
            source "$SCRIPT_ROOT/scripts/notify.sh"
            notify 'OpenVPN Authentication failed!' "$MESSAGE ($OPENVPN_CONFIG)" -u critical -a '[system]'
            sleep 5
            openvpn3 session-manage -c "$OPENVPN_CONFIG" --disconnect > /dev/null
            ;;
          *)
            printf '{"text": "%s", "tooltip": "%s"}\n' "$SYM_UNK"  "OpenVPN: $STATUS ($OPENVPN_CONFIG)"
            ;;
        esac
      done || true
    done
}
openvpn_toggle() {
  if openvpn3 sessions-list | grep '[Cc]onfig name: '"$OPENVPN_CONFIG" -q; then
    openvpn3 session-manage -c "$OPENVPN_CONFIG" --disconnect > /dev/null
  else
    openvpn3 session-start -c "$OPENVPN_CONFIG"
  fi
}
openvpn_kill() {
  pkill -f 'openvpn3 log -c '"$OPENVPN_CONFIG" || true
}

case "${1-}" in
  toggle)
    if $HAS_MULLVAD; then
      mullvad_toggle
    elif $HAS_OPENVPN; then
      openvpn_toggle
    fi
    ;;
  restart)
    if $HAS_MULLVAD; then
      mullvad_kill
    elif $HAS_OPENVPN; then
      openvpn_kill
    fi
    ;;
  *)
    if $HAS_MULLVAD; then
      mullvad_kill
      mullvad_status
    elif $HAS_OPENVPN; then
      openvpn_kill
      openvpn_status
    else
      printf '{"text": "%s", "tooltip": "%s"}\n' "$SYM_DIS" "No VPN service found"
    fi
esac

