#! /bin/bash
device wallpaper
numlockx on
pgrep -u "$USER" dunst        || dunst &
pgrep -u "$USER" keynav       || keynav &
pgrep -u "$USER" picom        || picom -CGbi 1 --shadow-exclude 'name ?= "cpt_frame_xcb_window" || name ?= "as_toolbar"' -- &
pgrep -u "$USER" redshift-gtk || redshift-gtk -l geoclue2 -t 6500K:2500K -b 1.0:0.7 &
pgrep -u "$USER" xss-lock     || xss-lock -l -- "$SCRIPT_ROOT/config/i3/lock.sh" & disown
pgrep -u "$USER" nm-applet    || nm-applet &
pgrep -u "$USER" -f 'browser_bridge_[s]erv.py' || "$SCRIPT_ROOT/browser/browser_bridge_serv.py" &

xset s 120 0
xset dpms 120 120 120

pgrep -u "$USER" xidlelock    || {
  xidlehook --detect-sleep \
    --timer 30 \
    'device if_should_pre_screen_save&disown' \
    '' \
    --timer 30 \
    'device if_should_pre_screen_save brightness save set 1 5000&disown' \
    'device brightness restore 20&disown' \
    --timer 30 \
    'device if_should_pre_screen_save&disown' \
    '' \
    --timer 29 \
    'device if_should_pre_screen_save&disown' \
    '' \
    &
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
