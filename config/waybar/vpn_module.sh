#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'


HAS_MULLVAD="$(command -v mullvad &>/dev/null && echo true || echo false)"
HAS_OPENVPN="$(command -v openvpn3 &>/dev/null && echo true || echo false)"


mullvad_parse() {
  while read -r INFO; do
    eval "$(jq -r '"STATE=\"\(.state)\"\n
                    COUNTRY=\"\(.details?.location?.country?)\"\n
                    CITY=\"\(.details?.location?.city?)\""' <<< "$INFO")"
    case "$STATE" in
      connected)
        printf '{"text": "%s", "tooltip": "%s"}\n' '  ' 'Mullvad: '"$COUNTRY ($CITY)"
        ;;
      disconnected)
        printf '{"text": "%s", "tooltip": "%s"}\n' "    " "No VPN"
        ;;
      *)
        printf '{"text": "%s", "tooltip": "%s"}\n' '    ' "Mullvad: $STATE"
        ;;
    esac
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

case "${1-}" in
  toggle)
    if $HAS_MULLVAD; then
      mullvad_toggle
    elif $HAS_OPENVPN; then
      :
    fi
    ;;
  *)
    if $HAS_MULLVAD; then
      mullvad status -j listen | mullvad_parse
    elif $HAS_OPENVPN; then
      :
    fi

    if ! $HAS_MULLVAD && ! $HAS_OPENVPN; then
      printf '{"text": "%s", "tooltip": "%s"}\n' "" "No VPN"
    fi
esac

