#!/bin/bash
# From xss-lock : /usr/share/doc/xss-lock/transfer-sleep-lock-swaylock.sh

# Example locker script -- demonstrates how to use the --transfer-sleep-lock
# option with swaylock's forking mode to delay sleep until the screen is locked.

## CONFIGURATION ##############################################################
LTARGET=1920x1080
BLUR=0x3.5
DESATURATE=100,50
SWAYLOCK_ARGS=(
    -F
    -c 000000
    --indicator-radius 60
    --inside-color      ffffff00
    --ring-color        00000000
    --inside-ver-color   003d991f
    --inside-clear-color 003d991f
    --text-clear-color   00000000
    --ring-clear-color   00000000
    --ring-ver-color     00000000
    --text-ver-color       669fff
    # --verif-text        '…'
    --inside-wrong-color e892002f
    --ring-wrong-color   00000000
    --text-wrong-color       f9e88e
    # --wrong-text        '!'
    # --noinput-text      ""
    # --lock-text         ""
    # --lockfailed-text   'failed'
    --line-uses-ring
    --key-hl-color       003d99
    --bs-hl-color        000a1a
    --separator-color   00000000
)
SWAYLOCK_OFFSET_FIX='+2+0'
CENTER="$HOME/Pictures/.lock/center.110.png"

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
    device dpms_on q notify_mode all screen_off # always reset this once we're locking and turn off screen
}

# Run after the locker exits
post_lock() {
    device q notify_mode all # restore notification state
    rm -f "/tmp/$USER/state/user_suspended"
    rm -f "/tmp/$USER/state/user_hibernated"
    rm -f "/tmp/$USER/state/system_sleeped"
    rm -f "/tmp/$USER/state/wokeup"
    rm -f "/tmp/$USER/state/locked"
    return
}

###############################################################################


lock() {
    pgrep swaylock &>/dev/null && return # don't lock twice
    pre_lock
    trap 'kill %%; post_lock' TERM INT
    prepare_lock
    getcache | xargs -d$'\n' swaylock "${SWAYLOCK_ARGS[@]}" -f
    postpare_lock

    wait_unlock& disown
}

unlock() {
    pkill -xu $EUID swaylock
    post_lock
}

wait_unlock() {
    kill_swaylock() {
        pkill -xu $EUID "$@" swaylock
    }
    cleanup() {
        kill_swaylock
        post_lock
    }
    trap cleanup EXIT
    while kill_swaylock -0; do
        sleep 0.5
    done
}

getcache() {
    local CACHE FILES HASH PTARGET
    readonly PTARGET="$(sed 's/^\([^x]*\)x\(.*\)/\2x\1/' <<< "$LTARGET")"
    readonly CACHE="${XDG_CACHE_DIR-"$HOME/.cache"}/lock"
    [ -d "$CACHE" ] || mkdir -p "$CACHE"
    FILES="$(swww query | sed 's/^: \([^:]*\): \([^,]*\)[^/]*\(.*\)/\1:\2:\3/')"
    while IFS=':' read -r OUT RES FILE; do
        {
            HASH="$(md5sum <<< "$FILE" | cut -c1-32)"
            if [ ! -f "$CACHE/${HASH}@${RES}.jpg" ]; then
                IFS=x read -r WIDTH HEIGHT <<< "$RES"
                if [ "$HEIGHT" -gt "$WIDTH" ]; then
                    TARGET="$PTARGET"
                else
                    TARGET="$LTARGET"
                fi
                magick \( "$FILE" -geometry "$TARGET^" -gravity center -crop "$TARGET+0+0" -modulate "$DESATURATE" -blur "$BLUR" -scale "$RES" \) \( "$CENTER" \) -geometry "$SWAYLOCK_OFFSET_FIX" -composite "$CACHE/${HASH}@${RES}.jpg"
            fi
            printf -- '-i\n%s:%s\n' "$OUT" "$CACHE/${HASH}@${RES}.jpg"
        }&
    done <<< "$FILES"
    wait
}


case "$1" in
    lock)   lock;;
    unlock) unlock;;
    cache) getcache;;
esac
