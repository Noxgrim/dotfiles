#! /bin/bash
[ -d  "/tmp/$USER" ] || mkdir -p "/tmp/$USER"
if [ -e "/tmp/$USER/sway/startup" ]; then
  device wallpaper brightness_reload
  rm -f "/tmp/$USER/sway/startup"
fi

# shellcheck disable=1091
source "$SCRIPT_ROOT/data/shared/local_env.sh"
pgrep -u "$USER" swww-daemon  || swww-daemon 2>/dev/null &
pgrep -u "$USER" dunst        || env ROFI_ACCENT=187.5 dunst &
pgrep -u "$USER" -f gammastep-indicator || gammastep-indicator -l "$GEO_LON:$GEO_LAT" -t 6500K:2500K -b 1.0:0.7 &
pgrep -u "$USER" nm-applet    || nm-applet &
pgrep -u "$USER" -f 'browser_bridge_[s]erv.py' || "$SCRIPT_ROOT/browser/browser_bridge_serv.py" &
swaymsg seat - hide_cursor 5000
swaymsg seat - hide_cursor when-typing enable

systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XAUTHORITY
dbus-update-activation-environment DISPLAY WAYLAND_DISPLAY XAUTHORITY
POLKIT_AGENT='/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1'
pgrep -uf "$USER" "$POLKIT_AGENT"    || "$POLKIT_AGENT" &
pgrep -uf "$USER" 'xdg-desktop-portal'    || /usr/lib/xdg-desktop-portal -r&
pgrep -uf "$USER" 'swayrd'    || swayrd&


eval "$(grep '^SSV_\w*=' "$(which device)")"

OFFSEC="$((SSV_TICK_LENGTH*SSV_OFF_TICKS))"


pgrep -u "$USER" swayidle    || {
  swayidle -w before-sleep "$SCRIPT_ROOT/config/sway/lock.sh   lock" \
                      lock "$SCRIPT_ROOT/config/sway/lock.sh   lock" \
                    unlock "$SCRIPT_ROOT/config/sway/lock.sh unlock"&

  declare -a XIH_ARGS=()
  declare TICK_FREQ=$SSV_TICK_LENGTH MAX="$((60*60-SSV_TICK_LENGTH))"
  for (( i=0; i<MAX; i+=TICK_FREQ )); do
    XIH_ARGS+=(
      timeout "$((i+TICK_FREQ))"
      'device screen_save_tick&disown'
    )
    if [[ "$i" = 0 ]]; then
      XIH_ARGS+=(
        resume
        'device screen_save_untick&disown'
      )
    fi
  done
  swayidle "${XIH_ARGS[@]}" &
  "$SCRIPT_ROOT/customlibs/swayidle-noinhibit" -I \
    timeout 1 \
    'true' \
    resume 'swaymsg output "*" power on' \
    timeout 3540 \
    'notify-send -u critical -a "[system]" "Inactivity" "Forcing screen off in 60s"' \
    resume 'notify-send -u critical -a "[system]" "Inactivity" "Forcing screen off in 60s" -t 1' \
    timeout 3600 \
    'notify-send -u critical -a "[system]" "Inactivity" "Forcing screen off in 60s" -t 1 && device screen_off' \
    \
    timeout 3900 \
    'device suspend' \
    \
    &
}
