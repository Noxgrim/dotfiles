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
    --inside-color       ffffff00
    --ring-color         00000000
    --inside-ver-color   d868881f # normal bg
    --inside-clear-color d868881f # normal bg
    --text-clear-color   00000000
    --ring-clear-color   00000000
    --ring-ver-color     00000000
    --text-ver-color     918ee8   # normal fg
    # --verif-text        '…'
    --inside-wrong-color e56e902f # urgent bg
    --ring-wrong-color   00000000
    --text-wrong-color   e59eb2   # urgent fg
    # --wrong-text        '!'
    # --noinput-text      ""
    # --lock-text         ""
    # --lockfailed-text   'failed'
    --line-uses-ring
    --key-hl-color       5b599c # normal bg
    --bs-hl-color        262541 # low bg
    --separator-color   00000000
)
SWAYLOCK_OFFSET_FIX='+2+0'
VAR=b # VARIANT
CENTER="$HOME/Pictures/.lock/center.110.${VAR}.png"

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
    dbus-send --system --print-reply \
        --dest=org.freedesktop.login1 /org/freedesktop/login1/session/auto \
              "org.freedesktop.login1.Session.SetLockedHint" boolean:true || true
    dbus-send --system --print-reply \
        --dest=org.freedesktop.login1 /org/freedesktop/login1/session/auto \
              "org.freedesktop.login1.Session.SetIdleHint" boolean:true || true
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
    dbus-send --system --print-reply \
        --dest=org.freedesktop.login1 /org/freedesktop/login1/session/auto \
              "org.freedesktop.login1.Session.SetLockedHint" boolean:false || true
    dbus-send --system --print-reply \
        --dest=org.freedesktop.login1 /org/freedesktop/login1/session/auto \
        "org.freedesktop.login1.Session.SetIdleHint" boolean:false || true
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
    local CACHE FILES HASH TWIDTH THEIGHT
    IFS=x read -r TWIDTH _ <<< "$LTARGET"
    readonly CACHE="${XDG_CACHE_DIR-"$HOME/.cache"}/lock" TWIDTH
    [ -d "$CACHE" ] || mkdir -p "$CACHE"
    FILES="$(swww query | sed 's/^: \([^:]*\): \([^,]*\)[^/]*\(.*\)/\1:\2:\3/;
                             1s/^[^:]*:[^:]*\(.*\)$/:'"$LTARGET"'\1\n&/')"
    while IFS=':' read -r OUT RES FILE; do
        {
            HASH="$(md5sum <<< "$FILE" | cut -c1-32)"
            if [ ! -f "$CACHE/${VAR}@${HASH}@${RES}.jpg" ]; then
                IFS=x read -r WIDTH HEIGHT <<< "$RES"
                THEIGHT="$(bc -l <<< "$TWIDTH/($WIDTH/$HEIGHT)")"
                if [ "$HEIGHT" -gt "$WIDTH" ]; then
                    TARGET="${THEIGHT}x${TWIDTH}"
                else
                    TARGET="${TWIDTH}x${THEIGHT}"
                fi
                # scale each image to a similar resolution (regarding aspect ratio)
                # to ensure similar blurring independent of input image size, then
                # crop it as swww would do
                # finally scale it up to output size and combine with center image
                # with slight offset as the circle in swaylock does not seem to
                # be entirely centered
                magick \( "$FILE" -geometry "$TARGET^" -gravity center -crop "$TARGET+0+0" -modulate "$DESATURATE" -blur "$BLUR" -scale "$RES" \) \
                    \( "$CENTER" \) -geometry "$SWAYLOCK_OFFSET_FIX" -composite "$CACHE/${VAR}@${HASH}@${RES}.jpg"
            fi
            printf -- '-i\n%s:%s\n' "$OUT" "$CACHE/${VAR}@${HASH}@${RES}.jpg"
        }&
    done <<< "$FILES"
    wait
}


case "$1" in
    lock)   lock;;
    unlock) unlock;;
    cache) getcache;;
esac
