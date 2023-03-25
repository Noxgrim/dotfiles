#!/bin/bash
IMG="/tmp/$USER/lock.png"
ARGS=()

# From xss-lock : /usr/share/doc/xss-lock/transfer-sleep-lock-i3lock.sh

# Example locker script -- demonstrates how to use the --transfer-sleep-lock
# option with i3lock's forking mode to delay sleep until the screen is locked.

## CONFIGURATION ##############################################################


# Run before starting the locker
pre_lock() {
    [ -d "/tmp/$USER" ] || mkdir -p "/tmp/$USER"
    return
}

# Prepare the actual locking
prepare_lock() {
    if [ -f "/tmp/$USER/user_suspended" ] || [ -f "/tmp/$USER/user_hibernated" ]; then
        mpc pause -q
    fi
    if grep -q 00black "$HOME/.fehbg"; then
        ARGS=( -C 000000 )
    else
        scrot "$IMG"
        mogrify -blur 20x20 "$IMG"
        ARGS=( -i "$IMG" )
    fi
}

# Run after the locker exits
post_lock() {
    [ -e "$IMG" ] && rm "$IMG"
    [ -f "/tmp/$USER/user_suspended" ] && rm "/tmp/$USER/user_suspended"
    [ -f "/tmp/$USER/user_hibernated" ] && rm "/tmp/$USER/user_hibernated"
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

    trap kill_i3lock TERM INT

    # we have to make sure the locker does not inherit a copy of the lock fd
    prepare_lock {XSS_SLEEP_LOCK_FD}<&-
    i3lock "${ARGS[@]}" -n -f {XSS_SLEEP_LOCK_FD}<&-

    # now close our fd (only remaining copy) to indicate we're ready to sleep
    exec {XSS_SLEEP_LOCK_FD}<&-

    while kill_i3lock -0; do
        sleep 0.5
    done
else
    trap 'kill %%' TERM INT
    prepare_lock
    i3lock "${ARGS[@]}" -n -f -i "$IMG"&
    wait
fi

post_lock
