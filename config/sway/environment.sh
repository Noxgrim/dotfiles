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


pgrep -u "$USER" swayidle    || {
  swayidle -w before-sleep "$SCRIPT_ROOT/config/sway/lock.sh   lock" \
                      lock "$SCRIPT_ROOT/config/sway/lock.sh   lock" \
                    unlock "$SCRIPT_ROOT/config/sway/lock.sh unlock" \
              after-resume "device post_wakeup"&

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
  XIH_ARGS=(
    -I
    timeout 0.1
    'true'
    resume 'swaymsg output "*" power on'
    timeout 5
    'true'
    resume 'device screen_save_untick&disown'
  )
  SECS=3540
  for (( i=SECS; i<3600; i++ )); do
      XIH_ARGS+=(
        timeout "$i"
        'source '"'$SCRIPT_ROOT/scripts/notify.sh'"'; notify -n inactive -R inactive -u critical -a "[system]" "Inactivity" "Forcing screen off in '$((3600-i))'s"'
      )
      [ "$i" = "$SECS" ] && XIH_ARGS+=(
        resume 'source '"'$SCRIPT_ROOT/scripts/notify.sh'"'; notify -k inactive'
      )
  done
  "$SCRIPT_ROOT/customlibs/swayidle-noinhibit" "${XIH_ARGS[@]}" \
    timeout 3600 \
    'source '"'$SCRIPT_ROOT/scripts/notify.sh'"'; notify -k inactive && device screen_off' \
    \
    timeout 3900 \
    'device suspend' \
    \
    &
}
