#!/bin/bash
# https://bbs.archlinux.org/viewtopic.php?pid=902722#p902722
execute() {
    local __RUN_FUNCTION=false __BACKGROUND=false __SHELL
    for ARG in "$@"; do
        case "$ARG" in
            -f) __RUN_FUNCTION=true; shift;;
            -b) __BACKGROUND=true; shift;;
            --) shift; break;;
            -*) echo "execute: Unknown argument! $ARG" >&2 && return 1;;
            *) break
        esac
    done

    local -a TARGETS __TARGET_USER_ID
    __TARGET_USER_ID="$(id -u "$USER")"
    __SHELL="$(getent passwd "$__TARGET_USER_ID" | cut -d: -f7 | sed 's,.*/,,g;s/^\(.\)/[\1]/')"
    TARGETS=('[i]3' '[k]smserver' '[t]mux: client' "$__SHELL")
    (
    _execute() {
        set -- "${@//"'"/"'\\''"}"; set -- "${@/#/"'"}"; set -- "${@/%/"'"}"
        local __OLD_IFS="$IFS" __CMD __BACKGROUND_SUFFIX=''
        if $__BACKGROUND; then
            __BACKGROUND_SUFFIX='&>/dev/null&echo $!'
        fi
        IFS=' ' __CMD="$*"
        IFS="$__OLD_IFS"
        if [ "$(whoami)" = "$USER" ]; then
            sh -c "$__CMD$__BACKGROUND_SUFFIX"
            __RET="$?"
        else
            su "$USER" -c "$__CMD$__BACKGROUND_SUFFIX"
            __RET="$?"
        fi
    }

    local __CMD __ACTIVE_TTY
    __ACTIVE_TTY="$(</sys/class/tty/tty0/active)"
    __ACTIVE_TTY="${__ACTIVE_TTY#tty}"
    IFS=$'\n'
    # shellcheck disable=2030
    for __TARGET in "${TARGETS[@]}"; do
        for __PID in $(pgrep -x "$__TARGET" -u "$__TARGET_USER_ID"); do
            eval "$(grep -z '^XDG_VTNR=' /proc/"$__PID"/environ | tr '\000' ' ')"
            if [ "$XDG_VTNR" != "$__ACTIVE_TTY" ]; then
                unset XDG_VTNR
                continue
            fi
            eval export "$(sed -z "/^__/d;s/'/'\\\\''/g"';s/=\(.*\)$/='"'\\1'/" /proc/"$__PID"/environ | tr '\000' ' ')"

            if $__RUN_FUNCTION; then
                "$@" || continue
            else
                _execute "$@"
            fi
            return "$__RET"
        done
    done
    )
}
notify() {
    # shellcheck disable=2034
    local _notify_send
    # shellcheck disable=2031,2317
    _notify_send() {
        case "$__TARGET" in
            '[i]3'|'[k]smserver')
                _execute notify-send "$@"
            ;;
            *)
                __RET=0
                local TTY_PATH
                TTY_PATH="$(readlink "/proc/$__PID/fd/0")"
                if [ "$TTY_PATH" != "/dev/$(cat /sys/class/tty/tty0/active)" ]; then
                    return 1
                fi
                local HEAD='' BODY='' URGENCY='normal' APP="$0" VAL='' next='' ARG ACTION='' NAME TEXT=''
                local -A ACTIONS
                for ARG in "$@"; do
                    if [ -n "$next" ]; then
                        eval "$next='${ARG//"'"/"'\\''"}'"
                        next=''
                    else
                        case "$ARG" in
                            --urgency=*) URGENCY="${ARG#--urgency=}";;
                            --app-name=*) APP="${ARG#--app-name=}";;
                            --hint=*) VAL="${ARG#--hint=}";;
                            --action=*) VAL="${ARG#--action=}";;
                            -u|--urgency) next=URGENCY;;
                            -a|--app-name) next=APP;;
                            -h|--hint) next=VAL;;
                            -A|--action) next=ACTION;;
                            *)
                                case "$(ps -o exe= $$)" in
                                    */bash)
                                        shopt -s extglob
                                        ARG="${ARG//<+([^>])>/}"
                                        shopt -u extglob
                                        ;;
                                    */zsh)
                                        setopt -o extendedglob
                                        ARG="${ARG//<+([^>])>/}"
                                        setopt +o extendedglob
                                        ;;
                                    *)
                                        echo 'Unknown shell!' >&2
                                esac
                                if [ -z "$HEAD" ]; then
                                    HEAD="$ARG"
                                else
                                    BODY="$ARG"
                                fi
                                ;;
                        esac
                    fi
                    if [ -n "$ACTION" ]; then
                        IFS='=' read -r NAME TEXT <<< "$ACTION"
                        ACTION=''
                        if [ -z "$TEXT" ]; then
                            ACTIONS["${#ACTIONS[@]}"]="$NAME"
                        else
                            ACTIONS["$NAME"]="$TEXT"
                        fi
                    fi
                done
                if [ "$URGENCY" = critical ]; then
                    case "$__TARGET" in
                        '[t]mux'*)
                            local -a ARGS=()
                            local FIFO=''
                            ARGS+=(-"$HEAD" '' '')
                            if [ -n "$VAL" ]; then
                                if [ -n "$BODY" ]; then
                                    BODY="$BODY (${VAL#*:}%)"
                                else
                                    BODY="Value: ${VAL#*:}%"
                                fi
                            fi
                            [ -n "$BODY" ] && ARGS+=(-"$BODY" '' '')
                            ARGS+=(-"(from $APP)" '' '')
                            if [ "${#ACTIONS[@]}" -gt 0 ]; then
                                ARGS+=('' '' '')
                                FIFO="$(mktemp -u "/tmp/notify.XXXXXXXXXXXX.fifo")"
                            fi
                            case "$(ps -o exe= $$)" in
                                */bash)
                                    for NAME in "${!ACTIONS[@]}"; do
                                        ARGS+=("${ACTIONS[$NAME]}" '' "run-shell 'echo $NAME > $FIFO'")
                                    done
                                    ;;
                                */zsh)
                                    # shellcheck disable=2066,2296
                                    for NAME in "${(@k)ACTIONS}"; do
                                        ARGS+=("${ACTIONS[$NAME]}" '' "run-shell 'echo $NAME > $FIFO'")
                                    done
                                    ;;
                                *)
                                    echo 'Unknown shell!' >&2
                            esac
                            ARGS+=('Ok' '' '')
                            tmux -S "/tmp/tmux-$__TARGET_USER_ID/default" display-menu -c "$TTY_PATH" \
                                -T "Notification ($URGENCY)" -C "$((${#ARGS[@]}/3))" -- \
                                 "${ARGS[@]}"
                            sleep 0.3
                            if [ -n "$FIFO" ]; then
                                touch "$FIFO"
                                head -n1 "$FIFO"
                                rm "$FIFO"
                            fi
                            ;;
                        *)
                            local STRING="Notification from $APP ($URGENCY):"$'\n'"$HEAD"
                            [ -n "$BODY" ] && STRING="$STRING"$'\n'"$BODY"
                            [ -n "$VAL" ]  && STRING="$STRING (${VAL#*:}%)"
                            printf '\n\r\e[91m---------------------------------------\e[0m\n\r%s\n\r\e[91m---------------------------------------\e[0m\n\r' "$STRING" >> "/proc/$__PID/fd/0"
                    esac
                fi
        esac
    }
    execute -f _notify_send "$@"
    unset -f _notify_send
}
