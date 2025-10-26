#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'


root="/tmp/$USER/sway/hacks/fs"
[ -d "$root" ] || mkdir -p "$root"

_fullscreen() {
  local app_id scratchpad con_id workspace pfx
  eval "$(swaymsg -t get_tree | jq -r\
      '..|
      select(.pid? and .focused==true)|
      "app_id=\(.app_id)\nscratchpad=\(.scratchpad_state)\ncon_id=\(.id)"' |\
    sed "s/'/'\\\\''/g;s/=/='/;s/$/'/")"
  workspace="$(swaymsg -t get_workspaces | jq -r '.[]|select(.focused==true)|.name')"
  if [ "$app_id" = 'terminal' ] || [ "$app_id" = 'terminal_fs' ]; then
    if [ ! -f "$root/$workspace" ]; then
      swaymsg -t get_tree |
        jq -r '..|
          select(.type? and .type == "workspace" and .name=="'"$workspace"'")|
          ..|
          select(.id?)|
          .id' > "$root/$workspace"
      pfx="$(find "$root" -mindepth 1 -maxdepth 1| tr -cd '\n' | tr '\n' '.' | sed 's/./​/')"
      swaymsg rename workspace to "$pfx" ';' \
        workspace "$workspace" ';' \
        gaps outer current set 0 ';' \
        gaps inner current set 0 ';' \
        exec "$SCRIPT_ROOT/scripts/terminal.sh --fs tmux new -session -As0"
      sed -i "s/^$con_id$/&*$scratchpad/" "$root/$workspace"
      echo ":$pfx" >> "$root/$workspace"
    else
      pfx="$(sed -n '/^:/s///p' "$root/$workspace")"
      swaymsg workspace "$pfx" ';'\
        '[workspace="'"$workspace"'"]' kill
      rm -f "$root/$workspace"
      sleep 0.1
      swaymsg rename workspace to "$workspace"
    fi
  else
    swaymsg fullscreen
  fi
}

_kill() {
  local app_id scratchpad con_id workspace pfx
  eval "$(swaymsg -t get_tree | jq -r\
      '..|
      select(.pid? and .focused==true)|
      "app_id=\(.app_id)\nscratchpad=\(.scratchpad_state)\ncon_id=\(.id)"' |\
    sed "s/'/'\\\\''/g;s/=/='/;s/$/'/")"
  workspace="$(swaymsg -t get_workspaces | jq -r '.[]|select(.focused==true)|.name')"

}

case "$1" in
  fullscreen)
    _fullscreen
    ;;
  kill)
    _kill
esac
