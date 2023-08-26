#!/usr/bin/env bash
THISDIR="$(dirname "$(readlink -f "$0")")"
source /root/notify.sh
source "$THISDIR/backup.conf"
CACHE="${XDG_CACHE_DIR-"$THISDIR/.cache"}/backup"

send_message() {
    notify -a backup -u "$1" "$2" "$3"
    echo "$2" "$3"
}

increase_skip() {
    [ -d "$CACHE" ] || mkdir -p "$CACHE"
    if [ -f "$CACHE/skipped" ]; then
        SKIPPED="$(cat "$CACHE/skipped")"
    else
        SKIPPED=0
    fi
    echo "$((SKIPPED+1))" > "$CACHE/skipped"
}

clear_skip() {
    [ -d "$CACHE" ] || mkdir -p "$CACHE"
    echo 0 > "$CACHE/skipped"
}

message_skip() {
    if [ -f "$CACHE/skipped" ]; then
        SKIPPED="$(cat "$CACHE/skipped")"
    else
        SKIPPED=0
    fi
    if [ "$SKIPPED" -lt 4 ]; then URG=low
    elif [ "$SKIPPED" -lt 10 ]; then URG=normal
    else URG=critical
    fi
    if [ "$SKIPPED" -lt 2 ]; then
        send_message "$URG" "$1" "$2"
    elif [ "$URG" != "critical" ]; then
        send_message "$URG" "$1" "$2 (×$SKIPPED)"
    else
        send_message "$URG" "$1" "$2 (<b><u>×$SKIPPED!</u></b>)"
    fi

}

if [ ! -e "/dev/disk/by-uuid/$DEVICEUUID" ]; then # check for existence
    SSHKEY="$(getent passwd "$USER_TARGET" | cut -d: -f6)"/.ssh/backup_ed25519
    for HOST in "${HOSTS[@]}"; do
        if ping -qc 1 -w 1 "$HOST" >/dev/null; then
            if ssh -i "$SSHKEY" backup@"$HOST"; then
                message_skip "Backup not possible" "Backup device not connected, \nbut <b>$HOST</b> should back up."
                clear_skip
                exit 0
            fi
        fi
    done
fi

# make it possible to suspend  backing up
if [ -e /tmp/backup_suspend ]; then
    increase_skip
    message_skip "Backup skipped" "Backup suspended."
    exit 0
fi
# don't backup while still backing up
if [ "$( pgrep -cf "bash $0" )" -gt 1 ]; then
    message_skip "Backup skipped" "There'\\''s already a backup running!"
    exit 0
fi
# don't backup while still backing up
if [ "$( pgrep -cf "borg" )" -gt 1 ]; then
    increase_skip
    message_skip "Backup skipped" "There'\\''s already some other <i>borg</i> running?"
    exit 0
fi

# mount backup drive
if [ ! -e "/dev/disk/by-uuid/$DEVICEUUID" ]; then # check for existence
    increase_skip
    # This shall annoy the user until they decide to backup again
    message_skip "Backup not possible" "Backup device not connected."
    exit 1;
fi

# Pass phrase
if [ -z "$(systemd-creds decrypt "$THISDIR/key")" ]; then
    send_message normal "Requesting backup keys" "Please provide if propmted"
    if [ -z "$(execute pass show /etc/backup)" ]; then
        increase_skip
        send_message critical "Backup not possible" "Key retrival failed!"
        exit 1
    fi
    execute pass show /etc/backup | systemd-creds encrypt - "$THISDIR/key" --not-after='+12h' -H
fi
BORG_PASSPHRASE="$(systemd-creds decrypt "$THISDIR/key" -)"
if ! grep -qs "$MOUNTLOC" /proc/mounts; then # only mount if not already mounted
    if [ ! -e "/dev/mapper/backup" ]; then
        cryptsetup open "/dev/disk/by-uuid/$DEVICEUUID" backup - <<< "$BORG_PASSPHRASE"
        DO_CLOSE=true
    else
        DO_CLOSE=false
    fi
    mount '/dev/mapper/backup' "$MOUNTLOC"
    DO_UMOUNT=true
else
    echo 'Already mounted.'
    DO_UMOUNT=false
    DO_CLOSE=false
fi



clear_skip
export BORG_PASSPHRASE
export BORG_BASE_DIR="$MOUNTLOC/data"
export REPOSITORY="$MOUNTLOC/borg/"
if [ -e "$REPOSITORY/lock.exclusive"  ]; then
    TIME="$(date +%s)"
    send_message critical "Backup: Detected lock!" "Attempting repair.\n<u>Keep device connected!</u>"
    borg break-lock "$REPOSITORY"
    export BORG_CHECK_I_KNOW_WHAT_I_AM_DOING=YES
    borg check --repair "$REPOSITORY"
    ETIME="$(date +%s)"
    TIME=$((ETIME-TIME))
    if [ "$TIME" -lt 3600 ]; then
        send_message normal "Backup repair finished." "Took $(TZ=UTC date +%M:%S -d@"$TIME").\nStarting normal backup."
    else
        send_message normal "Backup repair finished." "Took $(TZ=UTC date +%T    -d@"$TIME").\nStarting normal backup."
    fi

else
    borg break-lock "$REPOSITORY"
fi

send_message low "Backing up..." "<u>Keep device connected!</u>"
TIME="$(date +%s)"
OUT="$(mktemp)"
# Backup all of /home except a few excluded directories and files
borg create --verbose --stats --compression auto,zstd --list --filter AME \
        --show-rc                                        \
        "$REPOSITORY"::'{hostname}-{now:%Y-%m-%d %H:%M}' \
                                                         \
        --patterns-from <(
echo '
R /home
R /etc
R /root
R /var
R /root
R /mnt
'
locate /.backup_exclude | while read -r F; do
    E="$(sed 's,[&,\],\\&,' <<< "${F%/*}")"
    if    [ ! -s "$F" ]; then
        echo "P fm"$'\n'"! ${F%/*}"
    else
        sed '/^\s*#/d;/^\s*$/d;
        /^\(..\):\(.*\)/{s,,P \1\n!'"$E"'/\2,;b}
        s,^.*,P fm\n! '"$E/&," "$F"
    fi
done
echo '
+ /mnt/home
! /mnt/*
'
)                                       \
        --exclude-caches                \
        --exclude '/mnt/home/*/.cache'  \
        --exclude '/mnt/home/*/.ccache' \
        --exclude '/home/*/.cache'      \
        --exclude '/home/*/.ccache'     \
        --exclude '/var/cache/*'        \
        --exclude '/var/tmp/*'          \
        --exclude '/home/lost+found'    \
        --exclude '__pycache__'         \
        --exclude 'chache'              \
        --exclude 'chaches'             \
        --exclude '*.img'               \
        --exclude '*.iso'               \
        --exclude '*.rpa'               \
        --exclude '*.rpyc'              \
          &> "$OUT" # avoid log spam while log is updated
EXIT="$?"

cat "$OUT"
rm "$OUT"
# Route the normal process logging to journalctl
#2>&1

# Look at exit code
case "$EXIT" in
    0) # Everything fine
        CONTINUE=true
        MESSAGE_URGENCY=low
        MESSAGE_HEAD="Backup completed"
        MESSAGE_BODY=""
        ;;
    1) # Waring
        CONTINUE=true
        MESSAGE_URGENCY=low
        MESSAGE_HEAD="Backup completed"
        MESSAGE_BODY="<u>There were warinings!</u>\n"
        ;;
    2) # Error
        CONTINUE=false # we con't want to interact more with the repository
        MESSAGE_URGENCY=critical
        MESSAGE_HEAD="Backup may be incomplete!"
        MESSAGE_BODY="<u>An backup error occurred!</u>\n"
        ;;
    *) # Probably signal, https://github.com/borgbackup/borg/issues/6756
        CONTINUE=false
        MESSAGE_URGENCY=critical
        MESSAGE_HEAD="Backup may be incomplete!"
        MESSAGE_BODY="<u>An backup error occurred!</u>\nCode: $EXIT\n"
        ;;
esac

# Prune the repo of extra backups
$CONTINUE && prune -v "$REPOSITORY" --verbose -a '{hostname}-*' \
    --keep-hourly  16                                           \
    --keep-daily    7                                           \
    --keep-weekly   4                                           \
    --keep-monthly 12                                           \
    --keep-yearly  -1

# Include the remaining device capacity in the log
df -hl | grep --color=never "$MOUNTLOC"

$CONTINUE && borg list "$REPOSITORY"

# Unset the password
export BORG_PASSPHRASE=""
"$DO_UMOUNT" && umount "$MOUNTLOC"
"$DO_CLOSE" && cryptsetup close backup
ETIME="$(date +%s)"
TIME=$((ETIME-TIME))
if [ "$TIME" -lt 3600 ]; then
    send_message "$MESSAGE_URGENCY" "$MESSAGE_HEAD" "${MESSAGE_BODY}Took $(TZ=UTC date +%M:%S -d@"$TIME")"
else
    send_message "$MESSAGE_URGENCY" "$MESSAGE_HEAD" "${MESSAGE_BODY}Took $(TZ=UTC date +%T    -d@"$TIME")"
fi
exit 0
