#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'


[ "$(id -u)" != 0 ] && echo 'Must run as root!' >&2 && exit 1
USER_TARGET="${USER_TARGET-"$(id -nu 1000)"}"

special_vars() {
    clean() {
        sed -z -n '1d;/^[a-zA-Z_0-9]*=/b y;d;:y '"s/'/'\\\\''/g;"'s/=\(.*$\)/='"'\\1'"/';/^USER_TARGET/{p;b};s/^/USER_TARGET_/p' | sort -zu | tr '\000' ' ' | sed 's/^/readonly /'
    }
    # shellcheck disable=2016,2089
    local EXE='
    export USER_TARGET_CONFIG="${XDG_CONFIG_HOME="$HOME/.config"}"
    for N in DESKTOP DOWNLOAD TEMPLATES PUBLICSHARE DOCUMENTS MUSIC PICTURES VIDEOS; do
        eval "export USER_TARGET_$N=$(xdg-user-dir "$N")";
    done
    printf "\\0"
    env -0 -u EXE
    exit'
    # shellcheck disable=2090
    export EXE
    eval "$(expect - << EOF | clean
set send_slow {1 .05}
proc send {ignore arg} {
    sleep .05
    exp_send -s -- \$arg
}
set timeout -1
spawn -noecho sudo --preserve-env=EXE -i -u "$USER_TARGET"
sleep 0.2
send -- " eval \\"\\\$EXE\\"\\r"
expect eof
exit
EOF
)"
    unset -f clean
}



# shellcheck disable=2155
readonly THISDIR="$(dirname "$(readlink -f -- "$0")")"
special_vars
readonly CACHE="${XDG_CACHE_DIR-"$THISDIR/.cache"}/backup"
readonly SUSPEND_F="/tmp/backup_suspend"
readonly DISABLE_F="/tmp/backup_disable"
readonly SKIPPED_F="$CACHE/skipped"
readonly ARCHIVE_MOUNT_STATE_F="$CACHE/repo_mount_state"
readonly SKIP_RANSOM_F="$CACHE/skip_next_ransom"
readonly CONFIG_WORLD="$THISDIR/backup.conf.world"

write_config_world() {
    cat > "$CONFIG_WORLD" << EOF
# This file gets autogenerated each time bachup.sh is run.
# Documentation and actual values to edit can be found in backup.conf.
DEVICEUUID='$DEVICEUUID'
ALLOW_SUSPEND='$ALLOW_SUSPEND'
ALLOW_DISABLE='$ALLOW_DISABLE'
EOF
    chown root:root "$CONFIG_WORLD"
    chmod 644 "$CONFIG_WORLD"
}

send_message() {
    echo "$2" "${3-}" >&2
    notify -a backup -u "$@"
}

increase_skip() {
    local SKIPPED
    [ -d "$CACHE" ] || mkdir -p "$CACHE"
    if [ -f "$CACHE/skipped" ]; then
        SKIPPED="$(cat "$SKIPPED_F")"
    else
        SKIPPED=0
    fi
    echo "$((SKIPPED+1))" > "$SKIPPED_F"
}

clear_skip() {
    [ -d "$CACHE" ] || mkdir -p "$CACHE"
    echo 0 > "$SKIPPED_F"
}

do_ransom() {
    :
}

undo_ransom() {
    :
}

message_skip() {
    readonly HEAD="$1" BODY="$2" FORCE_LOW="${3-false}" FORCE_MESSAGE="${4-false}"
    local -a NOTIFY_ARGS=()
    local SKIPPED URG='' COUNTER EXTRA='' ACTION=''
    if [ -f "$SKIPPED_F" ]; then
        SKIPPED="$(<"$SKIPPED_F")"
    else
        SKIPPED=0
    fi

    $FORCE_LOW && [ -f "$SKIP_RANSOM_F" ] && rm "$SKIP_RANSOM_F"
    if ! $FORCE_LOW && [ "$SKIPS_RANSOM" != false ] && [ "$SKIPPED" -ge "$((SKIPS_RANSOM-1))" ]; then
        if [ "$SKIPPED" -ge "$SKIPS_RANSOM" ] && [ ! -f "$SKIP_RANSOM_F" ]; then
            URG=critical
            do_ransom
            COUNTER=" (<b><u>×$SKIPPED!</u></b>)"
            EXTRA="\nI now hold some (more) of your files for <b><u>ransom</u></b>. Connect your backup device to get them back!"
        elif [ "$SKIPPED" -ge "$((SKIPS_RANSOM-1))" ]; then
            [ -f "$SKIP_RANSOM_F" ] && rm "$SKIP_RANSOM_F"
            URG=critical
            COUNTER=" (<b><u>×$SKIPPED!</u></b>)"
            EXTRA="\nEnough is Enough! Next time I will hold some of your files for <b><u>ransom</u></b>. I would connect your backup device if I were you…"
        fi
    elif ! $FORCE_LOW && [ "$SKIPS_NOTIFICATION_CRITICAL" != false ] && [ "$SKIPPED" -ge "$SKIPS_NOTIFICATION_CRITICAL" ]; then
        URG=critical
        COUNTER=" (<b><u>×$SKIPPED!</u></b>)"
    elif ! $FORCE_LOW && [ "$SKIPS_NOTIFICATION_NORMAL" != false ] && [ "$SKIPPED" -ge "$SKIPS_NOTIFICATION_NORMAL" ]; then
        COUNTER=" (×$SKIPPED)"
        URG=normal
    elif [ "$SKIPS_NOTIFICATION_LOW" != false ] && [ "$SKIPPED" -ge "$SKIPS_NOTIFICATION_LOW" ]; then
        COUNTER=" (×$SKIPPED)"
        URG=low
    elif $FORCE_MESSAGE; then
        COUNTER=" (×$SKIPPED)"
        URG=low
    fi

    if [ "$SKIPPED" -lt 2 ]; then
        COUNTER=""
    fi
    if $ENABLE_NOTIFCATION_ACTIONS && $ALLOW_SUSPEND && [ ! -f "$SUSPEND_F" ]; then
        NOTIFY_ARGS+=( -A 'S=Suspend backup' )
    fi
    if $ENABLE_NOTIFCATION_ACTIONS && $ALLOW_DISABLE && [ ! -f "$DISABLE_F" ]; then
        NOTIFY_ARGS+=( -A 'D=Disable backup' )
    fi
    if [ ! -O "$DISABLE_F" ] && [ -n "$URG" ]; then
        if [ "${#NOTIFY_ARGS[@]}" -gt 0 ]; then
            escape() {
                set -- "${@//"'"/"'\\''"}"; set -- "${@/#/"'"}"; set -- "${@/%/"'"}"
                local IFS=' '
                echo "$*"
            }

            export    -f send_message notify execute
            read -r ACTION < <( timeout -s USR1 "${INTERACTION_TIMEOUT}s" bash -c "$(escape send_message "$URG" "$HEAD" "$BODY$COUNTER$EXTRA" "${NOTIFY_ARGS[@]}")" || echo; )
            export -n -f send_message notify execute
            unset -f escape
            case "$ACTION" in
                S)
                    touch "$SUSPEND_F"
                    chown --reference "$USER_TARGET_HOME" "$SUSPEND_F"
                    ;;
                D)
                    if execute zenity --question --text "Do you really want to supend and mute backups until reboot?"; then
                        touch "$DISABLE_F"
                        chown root:root "$DISABLE_F"
                    fi
                    ;;
                *)
                    ;;
            esac
        else
            send_message "$URG" "$HEAD" "$BODY$COUNTER$EXTRA"
        fi
    fi
}

check_other_devices() {
    local SSHKEY
    if [ ! -e "/dev/disk/by-uuid/$DEVICEUUID" ]; then # check for existence
        SSHKEY="$USER_TARGET_HOME/.ssh/backup_ed25519"
        # shellcheck disable=2153
        for HOST in "${HOSTS[@]}"; do
            [ "$HOST" = "$HOSTNAME" ] && continue
            if ping -qc 1 -w 1 "$HOST" >/dev/null; then
                if ssh -i "$SSHKEY" backup@"$HOST"; then
                    message_skip "Backup not possible" "Backup device not connected,\nbut <b>$HOST</b> should back up." true
                    clear_skip
                    exit 0
                fi
            fi
        done
    fi
}

check_should_run() {
    # make it possible to suspend  backing up
    if $ALLOW_DISABLE && [ -O "$DISABLE_F" ]; then
        increase_skip
        touch "$SKIP_RANSOM_F"
        exit 0
    fi
    if $ALLOW_SUSPEND && [ -e /tmp/backup_suspend ]; then
        increase_skip
        message_skip "Backup skipped" "Backup suspended."
        exit 0
    fi
    # don't backup while still backing up
    if [ "$( pgrep -cf "[b]ash $0" )" -gt 1 ]; then
        message_skip "Backup skipped" "There's already a backup running!" false true
        exit 0
    fi
    # don't backup while still backing up
    if [ "$( pgrep -cf '(^|/)[b]org ' )" -gt 0 ]; then
        increase_skip
        message_skip "Backup skipped" "There's already some other <i>borg</i> running?" false true
        exit 0
    fi
    if [ ! -e "/dev/disk/by-uuid/$DEVICEUUID" ]; then # check for existence
        increase_skip
        # This shall annoy the user until they decide to backup again
        message_skip "Backup not possible" "Backup device not connected."
        exit 1;
    fi
}


read_password_pass() {
    execute env PASSWORD_STORE_DIR="${PASS_STORE}" pass show "$PASS_PATH"
}

read_password_keepass() {
    local PASSWORD PINENTRY_COMMANDS PINENTRY_ERROR="" PINENTRY_OUT
    [ -e "$KEEPASS_DB" ] || return
    for ((TRIES=0; TRIES<3; TRIES++)); do
        if [ "$TRIES" -gt 0 ]; then
            PINENTRY_ERROR="SETERROR Wrong password, try again ($((3-TRIES)) attempts left)"
        fi
        PINENTRY_COMMANDS="
SETTITLE Open Backup
SETDESC Enter master password for KeePass database:%0A$KEEPASS_DB
$PINENTRY_ERROR
SETTIMEOUT $INTERACTION_TIMEOUT
GETPIN
BYE
"
        PINENTRY_OUT="$(execute pinentry <<< "$PINENTRY_COMMANDS" | sed '/^OK/d')"
        if grep '^D ' <<< "$PINENTRY_OUT" -q; then
            if PASSWORD="$(sed -n '/^D /s/^D //p' <<< "$PINENTRY_OUT" | \
                    keepassxc-cli show "$KEEPASS_DB" "$KEEPASS_PATH" -a Password -q)"; then
                echo "$PASSWORD"
                return
            fi
        else
            return 0
        fi
    done
}

wait_for_file() {
    readonly FILE="$1"
    local -i TIME=0 PID
    [ -z "$FILE" ] && echo 'wait_for_file: No file sepcified!' >&2 && exit 1
    [ -e "$1" ] && return

    PID="$(execute -b zenity --warning --text "Please make '$FILE' available, e.g. by mounting it!")"
    while [ ! -e "$FILE" ] && [ $TIME -lt "$PASSWORD_WAIT_FOR" ]; do
        sleep 3
        TIME=$((TIME+3))
    done
    kill "$PID" || true
    [ -e "$FILE" ]
}

request_password() {
    local PASSWORD
    send_message normal "Requesting backup keys" "Please provide if prompted"
    case "$PASSWORD_METHOD" in
        manager)
            case "$PASSWORD_MANAGER" in
                pass)
                    PASS_STORE="${PASS_STORE-"$USER_TARGET_HOME/.password-store"}"
                    wait_for_file "$PASS_STORE"
                    PASSWORD="$(read_password_pass)"
                    ;;
                keepass|keepassxc)
                    wait_for_file "$KEEPASS_DB"
                    PASSWORD="$(read_password_keepass)"
                    ;;
                *)
                    echo "Unsupported password manager: $PASSWORD_MANAGER" >&2 && exit 1
            esac
            ;;
        file)
            wait_for_file "$PASSWORD_FILE"
            [ ! -O "$PASSWORD_FILE" ] && send_message critical "Password file not owned by root!" && exit 1
            [[ "$(stat -c %a "$PASSWORD_FILE")" != ?00 ]] && send_message critical "Expected permissions *00 on password file!" && exit 1
            PASSWORD="$(<"$PASSWORD_FILE")"
            ;;
        variable)
            [ ! -O "$THISDIR/backup.conf" ] && send_message critical "Config file not owned by root!" && exit 1
            [[ "$(stat -c %a "$THISDIR/backup.conf")" != ?00 ]] && send_message critical "Expected permissions *00 on config file!" && exit 1
            PASSWORD="$PASSWORD_VAR"
            ;;
        *)
            echo "Unsupported password method: $PASSWORD_METHOD" >&2 && exit 1
    esac
    if [ -z "$PASSWORD" ]; then
        increase_skip
        send_message critical "Backup not possible" "Key retrival failed!"
        exit 1
    fi
    echo "$PASSWORD"
}

get_password_no_cache() {
    if ! $USE_ENCRYPTION; then
        echo ""
    else
        request_password
    fi
}

get_password() {
    local PASSWORD
    if ! $USE_ENCRYPTION; then
        echo ""
    elif [ "$PASSWORD_CACHE_TIME" == false ]; then
        request_password
    else
        PASSWORD="$(systemd-creds decrypt "$THISDIR/key"||true)"
        if [ -z "$PASSWORD" ]; then
            local -a CREDS_ENC_ARGS=(
                --with-key="$PASSWORD_CACHE_WITH_KEY"
            )
            if [ "$PASSWORD_CACHE_TIME" != 'nolimit' ]; then
                CREDS_ENC_ARGS+=(
                    --not-after="$PASSWORD_CACHE_TIME"
                )
            fi
            PASSWORD="$(request_password)" || exit 1
            systemd-creds encrypt - "$THISDIR/key" "${CREDS_ENC_ARGS[@]}" <<< "$PASSWORD"
            cmod 600 "$THISDIR/key"
        fi
        echo "$PASSWORD"
    fi
}

mount_device() {
    local MNT_SOURCE MOUNT_MESSAGE_HEAD="${1-"Backing up..."}"
    # mount backup drive
    PASSPHRASE="$(get_password)" || exit 1

    $NOTIFY_START && send_message low "$MOUNT_MESSAGE_HEAD" "<u>Keep device connected!</u>"
    TIME="$(date +%s)"

    # shellcheck disable=2174
    [ -d "$MOUNTLOC" ] || mkdir --mode 0700 -p "$MOUNTLOC"

    if $USE_FULL_DISK_ENCRYPTION; then
        MNT_SOURCE='/dev/mapper/backup'
    else
        MNT_SOURCE="/dev/disk/by-uuid/$DEVICEUUID"
    fi

    if ! findmnt --mountpoint "$MOUNTLOC" &>/dev/null; then # only mount if not already mounted
        if $USE_ENCRYPTION && $USE_FULL_DISK_ENCRYPTION && [ ! -e "/dev/mapper/backup" ]; then
            cryptsetup open "/dev/disk/by-uuid/$DEVICEUUID" backup - <<< "$PASSPHRASE"
            DO_CLOSE=true
        else
            DO_CLOSE=false
        fi
        mount "$MNT_SOURCE" "$MOUNTLOC"
        DO_UMOUNT=true
    else
        echo 'Already mounted.'
        DO_UMOUNT=false
        DO_CLOSE=false
    fi
    chown root:root "$MOUNTLOC"
    chmod 700 "$MOUNTLOC"

    $USE_ENCRYPTION && export BORG_PASSPHRASE_FD=3
    export BORG_BASE_DIR="$MOUNTLOC/$REPOSITORY_PATH/data"
    export BORG_REPO="$MOUNTLOC/$REPOSITORY_PATH/borg"
}

check_repair() {
    if [ -e "$BORG_REPO/lock.exclusive"  ] && $BACKUP_TRY_REPAIR; then
        TIME="$(date +%s)"
        send_message critical "Backup: Detected lock!" "Attempting repair.\n<u>Keep device connected!</u>"
        borg break-lock 3<<< "$PASSPHRASE"
        export BORG_CHECK_I_KNOW_WHAT_I_AM_DOING=YES
        borg check --repair 3<<< "$PASSPHRASE"
        ETIME="$(date +%s)"
        TIME=$((ETIME-TIME))
        if [ "$TIME" -lt 3600 ]; then
            send_message normal "Backup repair finished." "Took $(TZ=UTC date +%M:%S -d@"$TIME").\nStarting normal backup."
        else
            send_message normal "Backup repair finished." "Took $(TZ=UTC date +%T    -d@"$TIME").\nStarting normal backup."
        fi
        $NOTIFY_START && send_message low "Trying normal back up now..." "<u>Still keep device connected!</u>"
        TIME="$(date +%s)"
    else
        borg break-lock 3<<< "$PASSPHRASE"
    fi
}

do_backup() {
    local OUT EXIT CONTINUE MESSAGE_HEAD MESSAGE_BODY MESSAGE_URGENCY TIME_FMT
    OUT="$(mktemp)"
    chmod 600 "$OUT"
    borg list -a "*$BACKUP_KEEP_ARCHIVE_PATTERN" --first 1 3<<<"$PASSPHRASE" | grep -q . || \
        BACKUP_ARCHIVE_NAME="$BACKUP_ARCHIVE_NAME_FIRST_PREFIX$BACKUP_ARCHIVE_NAME"
    borg create --verbose --stats --compression "$BACKUP_COMPRESSION" --list --filter AME \
        --show-rc ::"$BACKUP_ARCHIVE_NAME" \
        --patterns-from <(
            echo "$BACKUP_PATTERN_ROOTS"
            echo "$BACKUP_PATTERN_PRE_EXCLUDE_FILE"
            locate /"$BACKUP_EXCLUDE_FILE" | while read -r F; do
            F="${F#/}"
            E="$(sed 's,[&,\],\\&,' <<< "${F%/*}")"
            if [ ! -s "$F" ]; then
                echo "P fm"$'\n'"! ${F%/*}"
            else
                sed '/^\s*#/d;/^\s*$/d;
                /^\(..\):\(.*\)/{s,,P \1\n! '"$E"'/\2,;b}
                s,^.*,P fm\n! '"$E/&," "$F"
            fi
        done
        echo "$BACKUP_PATTERN_POST_EXCLUDE_FILE"
    ) "${BACKUP_ARGS[@]}" 3<<< "$PASSPHRASE" \
        &> "$OUT" && true # avoid log spam while log is updated
    EXIT="$?"

    cat "$OUT"
    rm "$OUT"

    # Look at exit code
    case "$EXIT" in
        0) # Everything fine
            CONTINUE=true
            MESSAGE_URGENCY=low
            MESSAGE_HEAD="Backup completed"
            MESSAGE_BODY=""
            ;;
        1) # Warning
            CONTINUE=true
            MESSAGE_URGENCY=low
            MESSAGE_HEAD="Backup completed"
            MESSAGE_BODY="<u>There were warinings!</u>\n"
            ;;
        2) # Error
            CONTINUE=false # we don't want to interact more with the repository
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
    $CONTINUE && borg prune -s -v --verbose \
        -a "$BACKUP_KEEP_ARCHIVE_PATTERN" \
        --keep-hourly  "$BACKUP_KEEP_HOURLY" \
        --keep-daily   "$BACKUP_KEEP_DAILY" \
        --keep-weekly  "$BACKUP_KEEP_WEEKLY" \
        --keep-monthly "$BACKUP_KEEP_MONTHLY" \
        --keep-yearly  "$BACKUP_KEEP_YEARLY" 3<<< "$PASSPHRASE"

    # Include the remaining device capacity in the log
    df -hl | grep --color=never "$MOUNTLOC"

    $CONTINUE && borg list 3<<< "$PASSPHRASE"

    "$DO_UMOUNT" && umount "$MOUNTLOC"
    "$DO_CLOSE" && cryptsetup close backup
    ETIME="$(date +%s)"
    TIME=$((ETIME-TIME))
    TIME_FMT='+%M:%S'
    [ "$TIME" -lt 3600 ] || TIME_FMT='+%T'

    if $NOTIFY_END || ! $CONTINUE; then
        send_message "$MESSAGE_URGENCY" "$MESSAGE_HEAD" \
            "${MESSAGE_BODY}Took $(TZ=UTC date "$TIME_FMT" -d@"$TIME")"
    fi
    unset TIME ETIME PASSPHRASE
}

install_packages() {
    local COMMAND
    local -a PACKAGES=()
    local -A PACKAGE_OPTIONS
    # commands and packages on arch
    PACKAGE_OPTIONS['borg']='borg'
    PACKAGE_OPTIONS['cryptsetup']='cryptsetup'
    $INSTALL_DESKTOP_FILES && PACKAGE_OPTIONS['desktop-file-install']='desktop-file-util'
    PACKAGE_OPTIONS['expect']='expect'
    PACKAGE_OPTIONS['gpg']='gnupg'
    PACKAGE_OPTIONS['locate']='plocate'
    PACKAGE_OPTIONS['lsof']='lsof'
    PACKAGE_OPTIONS['notify-send']='libnotify'
    $INSTALL_DESKTOP_FILES && PACKAGE_OPTIONS['pkexec']='polkit'
    PACKAGE_OPTIONS['ssh']='openssh'
    PACKAGE_OPTIONS['xdg-user-dir']='xdg-user-dirs'
    PACKAGE_OPTIONS['zenity']='zenity'
    if [ "$PASSWORD_METHOD" = 'manager' ]; then
        case "$PASSWORD_MANAGER" in
            pass)
                PACKAGE_OPTIONS['pass']='pass'
                ;;
            keepass|keepassxc)
                PACKAGE_OPTIONS['keepassxc-cli']='keepassxc'
        esac
    fi

    for COMMAND in "${!PACKAGE_OPTIONS[@]}"; do
        if ! command -v "$COMMAND" &>/dev/null; then
            PACKAGES+=("${PACKAGE_OPTIONS[$COMMAND]}")
        fi
    done


    if [ "${#PACKAGES[@]}" -gt 0 ]; then
        pacman -Syu --needed "${PACKAGES[@]}"
    fi
}

setup_cmd() {
    local BUSER_HOME CONFIG="${1?"Please sepcify the config file!"}" USER_TARGET_ID
    BUSER_HOME="$(grep HOME /etc/default/useradd | cut -d= -f2-)"
    USER_TARGET_ID="$(id -u "$USER_TARGET")"
    BUSER_HOME="${BUSER_HOME-/home}/.backup"
    CONFIG="$(readlink -f -- "$CONFIG")"
    readonly BUSER_HOME CONFIG USER_TARGET_ID
    readonly UDEV_RULE='/etc/udev/rules.d/61-backup-root-mount.rules'
    # shellcheck disable=1090
    source "$CONFIG"
    local PASSWORD DEVPATH NEWLUKS=false CRYPTUUID="" FSUUID=""
    local BORG_REPO BORG_BASE_DIR
    readonly GNUPGHOME="$MOUNTLOC/$REPOSITORY_PATH/.gnupg" BORG_PASSPHRASE_FD=3
    # resolve symlinks to account for changing FS UUIDs
    DEVPATH="$(readlink -f "/dev/disk/by-uuid/${DEVICEUUID-xxxx}")"
    [ -e "$DEVPATH" ] || DEVPATH="$(readlink -f -- "$DEVICEPATH")"

    [ ! -e "$DEVPATH" ] && echo "Please connect specified backup device! (${DEVICEUUID-"$DEVICEPATH"})" >&2 && exit 1
    cp "$THISDIR/../scripts/notify.sh" /root
    # shellcheck disable=2016
    sed -i 's,\$(id -u "\$USER"),'"$USER_TARGET_ID"',g' /root/notify.sh # send messages to user
    # shellcheck disable=1091
    source /root/notify.sh

    systemd-analyze calendar "$BACKUP_FREQUENCY" || exit 1
    systemctl is-active -q backup.service && echo "Wait for backup to finish" && exit 1

    # Install necessary packages
    install_packages

    findmnt --mountpoint "$MOUNTLOC" &>/dev/null && umount "$MOUNTLOC"
    [ -e '/dev/mapper/backup' ] && cryptsetup close '/dev/mapper/backup'

    echo 'Reading password…'
    PASSWORD="$(get_password_no_cache)"
    readonly PASSWORD
    # init backup user
    if ! id -u backup &>/dev/null; then
        echo 'Setting up backup user…'
        mkdir --mode 700 "$BUSER_HOME"
        useradd --system -c 'Non-root backup tasks' --home "$BUSER_HOME" --shell "$BUSER_HOME/connected.sh" backup
        chown backup:backup "$BUSER_HOME"
        mkdir --mode 700 "$BUSER_HOME"/{.ssh,.gnupg}
        chown backup:backup "$BUSER_HOME"/{.ssh,.gnupg}
    fi
    echo 'Updating user files…'
    cp "$THISDIR/connected.sh" "$BUSER_HOME"
    chmod 755 "$BUSER_HOME/connected.sh"
    if [ ! -e "$USER_TARGET_HOME/.ssh/backup_ed25519" ]; then
        echo 'Creating check ssh key… (this is not relevant if you only use one machine)'
        execute ssh-keygen -f "$USER_TARGET_HOME/.ssh/backup_ed25519" -N '' -o -a 2048 -t ed25519 -C "$HOSTNAME-$(date -I); backup"
    fi
    # only allow one key
    cp "$USER_TARGET_HOME/.ssh/backup_ed25519.pub" "$BUSER_HOME/.ssh/authorized_keys"
    chmod 640 "$BUSER_HOME/.ssh/authorized_keys"
    chown backup:backup "$BUSER_HOME/.ssh/authorized_keys"
    cp "$THISDIR/backup.sh" "$BUSER_HOME"
    chmod 700 "$BUSER_HOME/backup.sh"
    cp "$CONFIG" "$BUSER_HOME/backup.conf"
    chmod 600 "$BUSER_HOME/backup.conf"

    # Setup full-disk-encryption
    if $USE_ENCRYPTION && $USE_FULL_DISK_ENCRYPTION; then
        if ! cryptsetup isLuks "$DEVPATH"; then
            echo "Setting up full-disk-encryption on $DEVPATH…"
            echo 'This is destructive! Continue? (Enter or Ctrl+C)'
            read -r _

            NEWLUKS=true
            # avoid creating a passphrase with a new line character
            printf '%s' "$PASSWORD" | cryptsetup -q luksFormat "$DEVPATH" -
        fi
        echo "Opening LUKS partition as ‘backup’…"
        CRYPTUUID="$(lsblk -no UUID "$DEVPATH")"
        cryptsetup open "$DEVPATH" backup - <<< "$PASSWORD"
        DEVPATH="/dev/mapper/backup"
    fi
    # File system
    if [ -z "$(lsblk -no FSTYPE "$DEVPATH")" ]; then
        if ! $NEWLUKS; then
            echo "Did not find a file system on $DEVPATH…"
            echo 'Setting one up. This is potentially destructive! Continue? (Enter or Ctrl+C)'
            read -r _
        else
            echo "Creating a file system…"
        fi
        mkfs.ext4 -qL backup "$DEVPATH"
    fi
    FSUUID="$(lsblk -no UUID "$DEVPATH")"
    echo "Mounting partition at ‘$MOUNTLOC’…"
    [ -d "$MOUNTLOC" ] || mkdir -p "$MOUNTLOC"
    mount "$DEVPATH" "$MOUNTLOC"
    chown root:root "$MOUNTLOC"
    chmod 700 "$MOUNTLOC"

    # borg
    $USE_ENCRYPTION && export BORG_PASSPHRASE_FD
    export BORG_BASE_DIR="$MOUNTLOC/$REPOSITORY_PATH/data"
    export BORG_REPO="$MOUNTLOC/$REPOSITORY_PATH/borg"

    [ -d "$BORG_BASE_DIR" ] || mkdir -p "$BORG_BASE_DIR"
    [ -d "$BORG_REPO" ] || mkdir -p "$BORG_REPO"

    if ! borg info 3<<< "$PASSWORD" &>/dev/null; then
        echo "Creating borg repository…"
        if $USE_ENCRYPTION; then
            borg init --encryption=repokey 3<<< "$PASSWORD"
        else
            borg init --encryption=none
        fi
    fi

    # gnupg
    export GNUPGHOME
    [ ! -d "$GNUPGHOME" ] && mkdir --mode 0700 "$GNUPGHOME"
    if ! gpg -K --with-colons 2>/dev/null| grep ^uid | cut -d: -f10 | grep '^Ransom$' -q; then
        echo "Creating gpg key…"
        gpg --yes --quick-gen-key --batch --passphrase-fd 0 \
            --pinentry-mode loopback 'Ransom' default default never <<< "$PASSWORD"
        gpg --export 'Ransom' | gpg --homedir "$BUSER_HOME/.gnupg" --import
    fi
    killall gpg-agent

    if ! umount "$MOUNTLOC"; then
        sleep 5
        umount "$MOUNTLOC"
    fi
    [ -e '/dev/mapper/backup' ] && cryptsetup close backup

    # UUID stuff
    if [ -n "$CRYPTUUID" ]; then
        echo "Updating UUID in config…"
        sed '/DEVICEUUID/s/\(DEVICEUUID=\).*/\1'"'$CRYPTUUID'/" -i "$BUSER_HOME/backup.conf"
        DEVICEUUID="$CRYPTUUID"
    elif [ -n "$FSUUID" ]; then
        echo "Updating UUID in config…"
        sed '/DEVICEUUID/s/\(DEVICEUUID=\).*/\1'"'$FSUUID'/" -i "$BUSER_HOME/backup.conf"
        DEVICEUUID="$FSUUID"
    fi

    if $ENFORCE_ROOT_MOUNT; then
        if [ ! -e "$UDEV_RULE" ]; then
            [ -d "${UDEV_RULE%/*}" ] || mkdir -p "${UDEV_RULE%/*}"
            cat >> "$UDEV_RULE" << EOF
# Disallow udiskie from mounting backup related devices in userspace
EOF
        fi
        if [ -n "$FSUUID" ]; then
            echo "Blocking non root mount for file system…"
            if ! grep "UUID=$FSUUID" -q '/etc/fstab'; then
                # Due to a bug in the KDE shell encryted devices still show up
                # (https://bugs.kde.org/show_bug.cgi?id=478643)
                # So we map it to /dev/null to cause an error. Fun.
                cat >> /etc/fstab << EOF
# backup only root
UUID=$FSUUID       /dev/null    ext4    noauto,rw,relatime,data=ordered,x-udisks-auth 0 2
EOF
            fi
            if ! grep 'ENV{ID_FS_UUID}=="'"$FSUUID"'"' -q "$UDEV_RULE"; then
                cat >> "$UDEV_RULE" << EOF
SUBSYSTEM=="block", ENV{ID_FS_UUID}=="$FSUUID", ENV{UDISKS_IGNORE}="1", ENV{UDISKS_SYSTEM}="1", ENV{UDISKS_PRE}="1", ENV{UDISKS_PRESENTATION_HIDE}="1", ENV{UDISKS_PRESENTATION_NOPOLICY}="1", ENV{UDISKS_AUTO}="0"
EOF
            fi
        fi
        if [ -n "$CRYPTUUID" ]; then
            echo "Setting options and prevent non-root mount for LUKS volume…"
            if ! grep "UUID=$CRYPTUUID" -q '/etc/crypttab'; then
                cat >> '/etc/crypttab' << EOF
# backup only root
backup    UUID=$CRYPTUUID    none    luks,timeout=90,discard,noauto,x-udisks-auth
EOF
            fi
            if ! grep 'ENV{ID_FS_UUID}=="'"$CRYPTUUID"'"' -q "$UDEV_RULE"; then
                cat >> "$UDEV_RULE" << EOF
SUBSYSTEM=="block", ENV{ID_FS_UUID}=="$CRYPTUUID", ENV{UDISKS_IGNORE}="1", ENV{UDISKS_SYSTEM}="1", ENV{UDISKS_PRESENTATION_HIDE}="1", ENV{UDISKS_PRESENTATION_NOPOLICY}="1", ENV{UDISKS_AUTO}="0"
EOF
            fi
        fi
        udevadm control --reload
    fi

    # systemd units
    echo "Setting up and stating systemd units…"
    cp "$THISDIR/backup."{service,timer} "$THISDIR/backup@.service" /etc/systemd/system
    systemctl disable backup.service backup.timer || true
    sed '/OnCalendar/s/\(OnCalendar\)\s=\s*.*/\1='"$BACKUP_FREQUENCY/" -i '/etc/systemd/system/backup.timer'
    sed '/^ExecStart/s/\(id -nu \)1000)/\1'"$USER_TARGET_ID)/" -i  '/etc/systemd/system/backup.service' '/etc/systemd/system/backup@.service'
    systemctl daemon-reload
    systemctl enable backup.timer
    systemctl start backup.timer

    if $INSTALL_DESKTOP_FILES; then
        local TEMDIR ACTION FILE EXEC
        local -A COMMENTS NAMES
        NAMES['backup']='Run backup'
        NAMES['mount']='Mount backup'
        NAMES['umount']='Umount backup'
        COMMENTS['backup']='Run a complete backup now'
        COMMENTS['mount']='Mount a backup archive or repository to browse it'
        COMMENTS['umount']='Unmount a previously mounted backup archive or repository'
        TEMDIR="$(mktemp -d '/tmp/desktop_files.XXXXXXXXXXX.d')"
        chmod 700 "$TEMDIR"
        for ACTION in backup mount umount; do
            FILE=backup
            $INSTALL_DESKTOP_FILES_FILES_FOR_ACTIONS && FILE="$ACTION"
            FILE="$TEMDIR/$FILE.desktop"

            if [ "$ACTION" = 'backup' ] || $INSTALL_DESKTOP_FILES_FILES_FOR_ACTIONS; then
                cat >> "$FILE" << EOF
[Desktop Entry]
Name=${NAMES["$ACTION"]}
Version=1.0
Comment=${COMMENTS["$ACTION"]}
GenericName=Backup
Keywords=System;Backup;Restore;Time Machine;File History
Type=Application
StartupNotify=true
Categories=System;Utility;Archiving;
EOF
            else
                cat >> "$FILE" << EOF

[Desktop Action $ACTION]
Name=${COMMENTS["$ACTION"]}
EOF
            fi
            if [ "$ACTION" = 'backup' ] && ! $INSTALL_DESKTOP_FILES_FILES_FOR_ACTIONS; then
                cat >> "$FILE" << EOF
Actions=mount;umount;
EOF
            fi
            if [ "$ACTION" = 'backup' ]; then
                EXEC='/bin/sh -c "pkexec systemctl start backup.service &>/dev/null"'
            else
                EXEC='/bin/sh -c "pkexec systemctl start backup@'$ACTION'.service &>/dev/null"'
            fi
            cat >> "$FILE" << EOF
Exec=$EXEC
EOF
        done
        desktop-file-install --vendor backup "$TEMDIR"/*.desktop
        rm -rf "$TEMDIR"
    fi

    write_config_world

    echo 'Done!'
}

init() {
    # shellcheck disable=1091
    source /root/notify.sh
    # shellcheck disable=1091
    source "$THISDIR/backup.conf"
}

backup_cmd() {
    init
    write_config_world
    check_other_devices
    check_should_run
    mount_device

    clear_skip
    undo_ransom

    check_repair
    do_backup
}

password_cmd() {
    init
    get_password
}

get_archive_mountloc() {
    if [ -z "$ARCHIVE_MOUNTLOC" ]; then
        ! $ARCHIVE_MOUNT_NON_ROOT_READ  && send_message critical 'Backup config error!' \
            'Cannot determine archive mount location.'$'\n''Not readable for non root users and ARCHIVE_MOUNTLOC empty!' && exit 1
        ARCHIVE_MOUNTLOC="/run/media/$USER_TARGET/backup_archive"
    fi
}

check_device_busy() {
    if lsof +f -F cn -- "$1" 2>/dev/null | grep -q .; then
        lsof +f -F c0n0 -- "$1" 2>/dev/null | \
            sed ':a /\x00$/{N;s/\x00\n/\x00/;b a;}' | sed -z '$d;s/^.//' | \
            execute xargs -r0 zenity --list --column PID --column Command --column File \
                --text "There are still files on '$1' open" --title "Cannot umount" \
                --cancel-label "" &>/dev/null || true
        exit 1
    fi
}

umount_cmd() {
    init
    local FORCE="${1?"Please specify an argument which may be empty or -f"}" ARCHIVE_MOUNT_STATE_F_LOC='' EC=0
    [ -e "$ARCHIVE_MOUNT_STATE_F" ] && ARCHIVE_MOUNT_STATE_F_LOC="$(readlink -f "$ARCHIVE_MOUNT_STATE_F")"
    readonly FORCE
    get_archive_mountloc

    if [ -e "$ARCHIVE_MOUNT_STATE_F" ]; then
        # shellcheck disable=1090
        source "$ARCHIVE_MOUNT_STATE_F"
    elif [ "$FORCE" = '-f' ]; then
        [ -h "$ARCHIVE_MOUNT_STATE_F" ] && rm "$ARCHIVE_MOUNT_STATE_F"
        [ -e '/dev/mapper/backup' ] && DO_CLOSE=true || DO_CLOSE=false
        findmnt --mountpoint "$MOUNTLOC" &>/dev/null && DO_UMOUNT=true || DO_UMOUNT=false
        findmnt --mountpoint "$ARCHIVE_MOUNTLOC" &>/dev/null && USED_ARCHIVE_MOUNTLOC="$ARCHIVE_MOUNTLOC"
    else
        [ -h "$ARCHIVE_MOUNT_STATE_F" ] && rm "$ARCHIVE_MOUNT_STATE_F"
        send_message critical 'Cannot unmount!' 'No priour mount detected' && exit 1
    fi

    if [ -n "${USED_ARCHIVE_MOUNTLOC-}" ] && findmnt --mountpoint "$USED_ARCHIVE_MOUNTLOC" &>/dev/null; then
        check_device_busy "$USED_ARCHIVE_MOUNTLOC"
        borg umount "$USED_ARCHIVE_MOUNTLOC" && true
        EC="$?"
        if [ $EC != 0 ]; then
            send_message critical 'Cannot unmount!' "Encountered error code $EC while trying to unmount borg." && exit 1
        fi
        [ -e "$ARCHIVE_MOUNT_STATE_F" ] && sed -i '/USED_ARCHIVE_MOUNTLOC/d' "$ARCHIVE_MOUNT_STATE_F_LOC"
        if [[ "$USED_ARCHIVE_MOUNTLOC" = /run/media/*/backup_archive ]]; then
            rmdir "$USED_ARCHIVE_MOUNTLOC"
            if ! find "${USED_ARCHIVE_MOUNTLOC%/*}" -mindepth 1 -maxdepth 1 | grep -q .; then
                rmdir "${USED_ARCHIVE_MOUNTLOC%/*}";
            fi
        fi
        sleep 2
    fi
    if $DO_UMOUNT; then
        check_device_busy "$MOUNTLOC"
        if ! umount "$MOUNTLOC"; then
            sleep 10

            umount "$MOUNTLOC" && true
            EC="$?"
            if [ $EC != 0 ]; then
                send_message critical 'Cannot unmount!' "Encountered error code $EC while trying to unmount $MOUNTLOC." && exit 1
            fi
        fi
        [ -e "$ARCHIVE_MOUNT_STATE_F" ] && sed -i '/DO_UMOUNT/d' "$ARCHIVE_MOUNT_STATE_F_LOC"
    fi

    if $DO_CLOSE; then
        cryptsetup close backup && true
        EC="$?"
        if [ $EC != 0 ]; then
            send_message critical 'Cannot unmount!' "Encountered error code $EC while trying to close encrypted volume." && exit 1
        fi
    fi
    if $DO_UMOUNT || $DO_CLOSE; then
        send_message low 'Unmounted backup device'
    fi


    [ -e "$ARCHIVE_MOUNT_STATE_F" ] && rm "$ARCHIVE_MOUNT_STATE_F_LOC"
    [ -h "$ARCHIVE_MOUNT_STATE_F" ] && rm "$ARCHIVE_MOUNT_STATE_F"
}


mount_cmd() {
    local ACTUAL_STATE_FILE WHAT="${1-}" TYPE=''
    init
    if [ -z "$WHAT" ]; then
        $ARCHIVE_MOUNT_REPO && WHAT='-r' || WHAT='-a'
    fi
    get_archive_mountloc

    if [ ! -e "/dev/disk/by-uuid/$DEVICEUUID" ]; then # check for existence
        send_message low 'Cannot mount' 'Backup device not connected.'
        exit 1;
    fi

    findmnt --mountpoint "$ARCHIVE_MOUNTLOC" &>/dev/null && send_message critical 'Cannot mount!' 'A borg archive is already mounted. Please umount it first.' && exit 1
    if systemctl is-active -q backup.service || [ "$( pgrep -cf '(^|/)[b]org ' )" -gt 0 ] ; then # check for existence
        send_message critical 'Cannot mount!' 'A backup or borg is already running.'$'\n''Please wait for its completion.' && exit 1
    fi

    mount_device 'Mounting backup device...'

    ACTUAL_STATE_FILE="$(mktemp "/tmp/backup-XXXXXXXXXXX.state")"
    chmod 600 "$ACTUAL_STATE_FILE"
    ln -sfr "$ACTUAL_STATE_FILE" "$ARCHIVE_MOUNT_STATE_F"
    cat > "$ARCHIVE_MOUNT_STATE_F" << EOF
DO_CLOSE=$DO_CLOSE
DO_UMOUNT=$DO_UMOUNT
EOF

    case "$WHAT" in
        -r)
            WHAT="$BORG_REPO"
            TYPE='Repository'
            ;;
        -a)
            local CHOICE
            if borg list -a "$ARCHIVE_MOUNT_FILTER_PATTERN" 3<<<"$PASSPHRASE" | grep -q .; then
                CHOICE="$(borg list --format '{time}{NUL}{name}{NUL}' \
                    -a "$ARCHIVE_MOUNT_FILTER_PATTERN" 3<<<"$PASSPHRASE" |\
                    sed -z '1!G;h;$!d' | execute xargs -r0 zenity --list \
                    --title "Select archive to mount" --text "(Newest shown first)" --column Name --column Created || true)"
                if [ -z "$CHOICE" ]; then
                    umount_cmd ''
                    exit 1
                fi
                WHAT="::$CHOICE"
            else
                send_message low 'Cannot mount.' 'No sutable archives found.'$'\n''Consider adjusting the filters.'
                umount_cmd ''
                exit 1
            fi
            TYPE='Archive'
            ;;
        *)
            umount_cmd ''
            echo 'What is your WHAT?!' >&2 && exit 1
    esac

    local -a ARGS=( mount "$WHAT" "$ARCHIVE_MOUNTLOC" )
    $ARCHIVE_MOUNT_NON_ROOT_READ && ARGS+=( -o allow_other )

    mkdir -p "$ARCHIVE_MOUNTLOC"
    $ARCHIVE_MOUNT_NON_ROOT_READ && chown "$USER_TARGET:$USER_TARGET" "$ARCHIVE_MOUNTLOC"
    if [ "$ARCHIVE_MOUNTLOC" = "/run/media/$USER_TARGET/backup_archive" ]; then
        setfacl --set 'user::rwx,user:'"$USER_TARGET"':r-x,group::r-x,mask::r-x,other::---' \
            "${ARCHIVE_MOUNTLOC%/*}"
    else
        chmod 700 "$ARCHIVE_MOUNTLOC"
    fi

    borg "${ARGS[@]}" 3<<< "$PASSPHRASE" && true
    EC="$?"
    if [ $EC != 0 ]; then
        send_message critical 'Cannot mount!' "Encountered error code $EC while trying to borg mount."
        unmount_cmd
        exit 1
    fi
    cat >> "$ARCHIVE_MOUNT_STATE_F" << EOF
USED_ARCHIVE_MOUNTLOC=$ARCHIVE_MOUNTLOC
EOF
    send_message low "$TYPE mounted" "Browse at ‘$ARCHIVE_MOUNTLOC’"
}

main() {
    case "${1-backup}" in
        setup)
            setup_cmd "${2?"Please provide a config file to use."}"
            ;;
        backup)
            backup_cmd
            ;;
        password)
            password_cmd
            ;;
        mount)
            mount_cmd "${2-}"
            ;;
        umount|unmount)
            umount_cmd "${2-}"
            ;;
        *)
            cat << 'EOF'
Usage:
 start with `~backup/backup.sh`
 To define another user to target set evironment variable USER_TARGET
 (default is user with id 1000).
 `sudo env USER_TARGET="$USER" ~backup/backup.sh`
Options:
    backup
        Perform a backup now
    setup CONFIG_FILE
        Initialize and setup system for automatic backups
    password
        Print backup password to stdout, requesting it if necessary
    mount [-a|-r]
        Prompt for a borg archive and mount it
        If -r is given, mount a whole repository
        If -a is given, mount a specified archive
        fi
    umount [-f]
        Unmount previously mounted borg archive
        If -f is given, try to do that even if no prior mount was detected
EOF
            ;;
    esac
}

main "$@"
exit 0
