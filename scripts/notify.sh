# https://bbs.archlinux.org/viewtopic.php?pid=902722#p902722
execute() {
    set -- "${@//"'"/"'\\''"}"; set -- "${@/#/"'"}"; set -- "${@/%/"'"}"
    local -a TARGETS
    if pgrep -x i3 >/dev/null; then
        TARGETS+=(i3)
    fi
    if pgrep -x ksmserver >/dev/null; then
        TARGETS+=(ksmserver)
    fi
    if [ "${#TARGETS[@]}" = 0 ]; then
        TARGETS+=(zsh)
    fi
    (
    for TARGET in "${TARGETS[@]}"; do
        for pid in $(pgrep -x "$TARGET" -u "$(id -u "$USER")"); do
            eval export "$(sed -z "s/'/'\\\\''/g"';s/=\(.*\)$/='"'\\1'/" /proc/"$pid"/environ | tr '\000' ' ')"

            export IFS=' '
            if [ "$(whoami)" = "$USER" ]; then
                sh -c "$*"
            else
                su "$USER" -c "$*"
            fi
            return "$?"
        done
    done
    )
}
notify() {
    execute 'notify-send' "${@}"
}
