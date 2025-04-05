#! /bin/bash
device wallpaper
numlockx on
[ -d  "/tmp/$USER" ] || mkdir -p "/tmp/$USER"
touch "/tmp/$USER/picom_lock.conf"
pgrep -u "$USER" dunst        || dunst &
pgrep -u "$USER" keynav       || keynav &
pgrep -u "$USER" picom        || picom &
pgrep -u "$USER" redshift-gtk || redshift-gtk -l geoclue2 -t 6500K:2500K -b 1.0:0.7 &
pgrep -u "$USER" xss-lock     || xss-lock -l -- "$SCRIPT_ROOT/config/i3/lock.sh" & disown
pgrep -u "$USER" nm-applet    || nm-applet &
pgrep -u "$USER" -f 'browser_bridge_[s]erv.py' || "$SCRIPT_ROOT/browser/browser_bridge_serv.py" &
pgrep -u "$USER" unclutter    || unclutter --timeout 1 --ignore-scrolling --jitter 50 --fork

eval "$(grep '^SSV_\w*=' "$(which device)")"

OFFSEC="$((SSV_TICK_LENGTH*SSV_OFF_TICKS))"

xset s "$OFFSEC" 0
xset dpms "$OFFSEC" "$OFFSEC" "$OFFSEC"

pgrep -u "$USER" xidlelock    || {
  declare -a XIH_ARGS=()
  declare TICK_FREQ=$SSV_TICK_LENGTH MAX="$((60*60-SSV_TICK_LENGTH))"
  for (( i=0; i<MAX; i+=TICK_FREQ )); do
    XIH_ARGS+=(
      --timer "$TICK_FREQ"
      'device screen_save_tick&disown'
      'device screen_save_untick&disown'
    )
  done
  xidlehook --detect-sleep "${XIH_ARGS[@]}" &
  xidlehook --detect-sleep \
    --timer 3540 \
    'notify-send -u critical -a "[system]" "Inactivity" "Forcing screen off in 60s"' \
    'notify-send -u critical -a "[system]" "Inactivity" "Forcing screen off in 60s" -t 1' \
    --timer 60 \
    'notify-send -u critical -a "[system]" "Inactivity" "Forcing screen off in 60s" -t 1 && device screen_off' \
    '' \
    --timer 300 \
    'device suspend' \
    '' \
    &
}
