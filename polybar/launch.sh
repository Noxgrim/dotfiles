#!/usr/bin/env bash

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

source "$HOME/.device_specific/monitor_names.sh"

# Launch bar1 and bar2
echo "---" | tee -a /tmp/polybar1.log /tmp/polybar2.log
polybar bar_poly_primary >>/tmp/polybar1.log 2>&1 &
polybar bar_poly_secondary >>/tmp/polybar2.log 2>&1 &


sleep 0.5
if pgrep compton; then
    source "$HOME/dotfiles/i3/notify.sh"
    killall compton
    execute 'compton -CGb &> /dev/null & disown'
fi

polybar-msg cmd hide
