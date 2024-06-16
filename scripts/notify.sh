# https://bbs.archlinux.org/viewtopic.php?pid=902722#p902722
execute() {
    set -- "${@//"'"/"'\\''"}"; set -- "${@/#/"'"}"; set -- "${@/%/"'"}"
    local -a TARGETS
    if pgrep -x i3 >/dev/null; then
        TARGETS+=('[i]3')
    fi
    if pgrep -x ksmserver >/dev/null; then
        TARGETS+=('[k]smserver')
    fi
    if [ "${#TARGETS[@]}" = 0 ]; then
        TARGETS+=('[z]sh')
    fi
    (
    for TARGET in "${TARGETS[@]}"; do
        for pid in $(pgrep -x "$TARGET" -u "$(id -u "$USER")"); do
            local CMD
            IFS=' ' CMD="$*"
            eval export "$(sed -z "s/'/'\\\\''/g"';s/=\(.*\)$/='"'\\1'/" /proc/"$pid"/environ | tr '\000' ' ')"

            if [ "$(whoami)" = "$USER" ]; then
                sh -c "$CMD"
            else
                su "$USER" -c "$CMD"
            fi
            return "$?"
        done
    done
    )
}
notify() {
    execute 'notify-send' "${@}"
}
