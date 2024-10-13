#!/bin/bash
# From xss-lock : /usr/share/doc/xss-lock/transfer-sleep-lock-i3lock.sh

# Example locker script -- demonstrates how to use the --transfer-sleep-lock
# option with i3lock's forking mode to delay sleep until the screen is locked.

## CONFIGURATION ##############################################################

PICOM_CONF="$SCRIPT_ROOT/config/picom/picom.conf"
PICOM_LOCK="$SCRIPT_ROOT/config/picom/lock.conf"
I3LOCK_ARGS=(
    -f
    -c 00000000
    --radius 60
    --inside-color      1111114f
    --ring-color        00000000
    --insidever-color   003d997f
    --ringver-color     00000000
    --verif-color       669fff
    --verif-text        '…'
    --insidewrong-color e892007f
    --ringwrong-color   00000000
    --wrong-color       f9e88e
    --wrong-text        '!'
    --modif-color       ffffff7f
    --noinput-text      ""
    --lock-text         ""
    --lockfailed-text   'failed'
    --line-uses-ring
    --keyhl-color       003d99
    --bshl-color        000a1a
    --separator-color   00000000

    --pass-volume
    --pass-screen
    --custom-key-commands
    --cmd-media-play  "$SCRIPT_ROOT/audioscripts/audio.sh t"
    --cmd-media-pause "$SCRIPT_ROOT/audioscripts/audio.sh t"
    --cmd-media-stop  "$SCRIPT_ROOT/audioscripts/audio.sh !"
    --cmd-media-next  "$SCRIPT_ROOT/audioscripts/audio.sh j"
    --cmd-media-prev  "$SCRIPT_ROOT/audioscripts/audio.sh k"
)

# Run before starting the locker
pre_lock() {
    [ -d "/tmp/$USER/state" ] || mkdir -p "/tmp/$USER/state"
}

# Prepare the actual locking
prepare_lock() {
    killall rofi rofi-theme-selector dmenu 2>/dev/null || true
}

# prepare actual locking after locking command executed
postpare_lock() {
    if [ -f "/tmp/$USER/state/user_suspended" ] || [ -f "/tmp/$USER/state/user_hibernated" ]; then
        mpc pause -q
    elif [ "$(loginctl show-session --property=PreparingForSleep | cut -d= -f2)" == 'yes' ] || [ -f "/tmp/$USER/state/wokeup" ]; then
        mpc pause -q
        touch "/tmp/$USER/state/system_sleeped"
    fi
    touch "/tmp/$USER/state/locked"
    device dpms_on screen_off q notify_mode lock # always reset this once we're locking and turn off screen
    local FENCE
    if [ -e "/tmp/$USER/lock_show_desktop_only" ]; then
        FENCE='LOCKED DESKTOP'
    else
        FENCE='LOCKED'
    fi
    sed  '
    /{{{'"$FENCE"'}}}/,/{{{\/'"$FENCE"'}}}/{
        /{{{\/\?'"$FENCE"'}}}/b;s/^\(\s*\)\(\s*#\s\)*/\1/
    }
    /@include/d' \
        "$PICOM_CONF" > "$PICOM_LOCK"
}

# Run after the locker exits
post_lock() {
    echo '' > "$PICOM_LOCK"
    device q notify_mode restore # restore notification state
    [ -f "/tmp/$USER/state/user_suspended"  ] && rm "/tmp/$USER/state/user_suspended"
    [ -f "/tmp/$USER/state/user_hibernated" ] && rm "/tmp/$USER/state/user_hibernated"
    [ -f "/tmp/$USER/state/system_sleeped"  ] && rm "/tmp/$USER/state/system_sleeped"
    [ -f "/tmp/$USER/state/wokeup"          ] && rm "/tmp/$USER/state/wokeup"
    [ -f "/tmp/$USER/state/locked"          ] && rm "/tmp/$USER/state/locked"
    return
}

###############################################################################

pre_lock

# We set a trap to kill the locker if we get killed, then start the locker and
# wait for it to exit. The waiting is not that straightforward when the locker
# forks, so we use this polling only if we have a sleep lock to deal with.
if [[ -e /dev/fd/${XSS_SLEEP_LOCK_FD:--1} ]]; then
    kill_i3lock() {
        pkill -xu $EUID "$@" i3lock
    }
    cleanup() {
        kill_i3lock
        post_lock
    }

    trap cleanup TERM INT

    # we have to make sure the locker does not inherit a copy of the lock fd
    prepare_lock {XSS_SLEEP_LOCK_FD}<&-
    i3lock "${I3LOCK_ARGS[@]}" {XSS_SLEEP_LOCK_FD}<&-
    postpare_lock {XSS_SLEEP_LOCK_FD}<&-

    # now close our fd (only remaining copy) to indicate we're ready to sleep
    exec {XSS_SLEEP_LOCK_FD}<&-

    while kill_i3lock -0; do
        sleep 0.5
    done
else
    trap 'kill %%; post_lock' TERM INT
    prepare_lock
    i3lock "${I3LOCK_ARGS[@]}" -n &
    postpare_lock
    wait
fi

post_lock
