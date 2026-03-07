#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n'

ROFI_THEME=$(cat << EOF
window {
    location:center;
    y-offset:0;
}
listview {
    flow: horizontal;
    lines:      4;
    columns:    2;
    dynamic: true;
    expand: true;
}
EOF
)

# id,destop portal expected id,rofi tags,rofi string,slurp dims,visible
readarray monitors < <(swaymsg -t get_outputs | \
    jq -r '.[]|select(.active)|"\(.name)\tMonitor: \(.name
            )\tmonitor output\(if .focused then " focused" else "" end
            )\t"+@html "<i>\(.name)</i>\u001c<b>\(.model
            )\(if .focused then " 󰈈" else "" end)</b>\u001c<span alpha=\"40%\">\(.make
            )</span>"+"\t\(.rect.x),\(.rect.y) \(.rect.width)x\(.rect.height
            ) Monitor: \(.name)\ttrue"' | sort)

readarray windows < <(swaymsg -t get_tree | jq -r\
  '.. | select(.type? == "output") | .name as $out |
   .. | select(.type? == "workspace") | .name as $ws |
   .. | select(.foreign_toplevel_identifier?) | .foreign_toplevel_identifier as $id | "\($id
       )\tWindow: \($id)\twindow \(if .visible then "visible" else "hidden" end
       )\(if .focused then " focused" else "" end)\(if .urgent then " urgent" else "" end
       )\t"+ @html "<i>\(.app_id // .window_properties.class)</i>\u001c<b>\(.name
       )</b>\u001c<span alpha=\"60%\">on \"\($ws)\" (\($out
       ))\(if .marks[0]? then " \(.marks)" else "" end)\(if .focused then " 󰈈"
        elif .visible then " 󰛐" else "" end)</span>"+"\t\(.rect.x
       ),\(.rect.y) \(.rect.width)x\(.rect.height) Window: \($id)\t\(.visible)"')
special=($'.icon-select\t@select\tselect\t<i>Select visible</i>\t\t')

DIR="/tmp/$USER/wlr-screencast"
[ -d "$DIR" ] || mkdir -p "$DIR"
cleanup () {
  rm -rf "$DIR"
}
trap cleanup EXIT

printf '%s' "${windows[@]}"  | cut -d$'\t' -f1 | xargs -P0 -I{} grim -t jpeg -T {} -q 5 "$DIR/{}.jpg"&
printf '%s' "${monitors[@]}" | cut -d$'\t' -f1 | xargs -P0 -I{} grim -t jpeg -o {} -q 5 "$DIR/{}.jpg"&
ln -sfr "$SCRIPT_ROOT/assets/screencast/icon-select" "$DIR/.icon-select.jpg"
wait

export ROFI_WIDTH=80% ROFI_ACCENT=36.0 ROFI_ICON_SIZE=8em

SELECTION="$(printf '%s' "${monitors[@]}" "${windows[@]}" "${special[@]}" | \
  sed 's|^\([^\t]*\)\t\([^\t]*\t[^\t]*\t[^\t]*\).*|\2\x00icon\x1f'"$DIR"'/\1.jpg|' | tr '\034\n' '\n\034' | \
  rofi -dmenu -sep $'\034' -display-column-separator $'\t' -display-columns 3 -markup-rows -i \
  -p 'Screen share'  -theme-str "$ROFI_THEME" | tr '\034\n' '\n\034' | cut -d$'\t' -f1 || echo '')"
case "$SELECTION" in
  '')
    exit 1
    ;;
  @select)
    printf '%s'  "${monitors[@]}" "${windows[@]}" | grep 'true$' | cut -d$'\t' -f5 | slurp -rf '%l'
    ;;
  *)
    printf '%s' "$SELECTION"
    ;;
esac
