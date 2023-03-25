#! /bin/bash
source "$HOME/.device_specific/wallpaper_command.sh"
numlockx on
pgrep -u "$USER" dunst        || dunst &
pgrep -u "$USER" keynav       || keynav &
pgrep -u "$USER" picom        || picom -CGbi 1 --shadow-exclude 'name ?= "cpt_frame_xcb_window" || name ?= "as_toolbar"' -- &
pgrep -u "$USER" redshift-gtk || redshift-gtk -l geoclue2 -t 6500K:2500K -b 1.0:0.7 &
pgrep -u "$USER" xss-lock     || xss-lock -l -- "$SCRIPT_ROOT/config/i3/lock.sh" & disown
pgrep -u "$USER" nm-applet    || nm-applet &

xset s 120 0
xset dpms 120 120 120

pgrep -u "$USER" xidlelock    || {
  xidlehook --detect-sleep --not-when-fullscreen \
    --timer 60 \
    '[ -d "/tmp/$USER" ] || mkdir "/tmp/$USER";
     xbacklight -get > "/tmp/$USER/xbacklight" &&
     xbacklight -steps 500 -time 5000 -set 1&disown' \
    "pkill -f $'\\x2fusr/sbin/xbacklight'"' || true;
     xbacklight -set "$(cat "/tmp/$USER/xbacklight")" -time 20 -steps 2' &
  xidlehook --detect-sleep \
    --timer 3540 \
    'notify-send -u critical -a "[system]" "Inactivity" "Forcing screen off in 60s"' \
    'notify-send -u critical -a "[system]" "Inactivity" "Forcing screen off in 60s" -t 1' \
    --timer 60 \
    'notify-send -u critical -a "[system]" "Inactivity" "Forcing screen off in 60s" -t 1 && "$HOME/.i3/device.sh" screen_off' \
    '' \
    --timer 300 \
    'device suspend' \
    '' &
}
