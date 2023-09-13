# https://bbs.archlinux.org/viewtopic.php?pid=902722#p902722
notify() {
    set -- "${@//"'"/"'\\''"}"; set -- "${@/#/"'"}"; set -- "${@/%/"'"}"
    for pid in $(pgrep -x 'i3' -u "$(id -u "$USER")"); do
        eval "$(grep -z ^USER /proc/"$pid"/environ | tr '\000' '\n')"
        eval export "$(grep -z ^DISPLAY /proc/"$pid"/environ | tr '\000' '\n')"
        eval export "$(grep -z ^DBUS_SESSION_BUS_ADDRESS /proc/"$pid"/environ | tr '\000' '\n')"

        export IFS=' '
        if [ "$(whoami)" = "$USER" ]; then
            sh -c "notify-send  $*"
        else
            su "$USER" -c "notify-send  $*"
        fi
        echo "$1 $2"
    done
}
execute() {
    set -- "${@//"'"/"'\\''"}"; set -- "${@/#/"'"}"; set -- "${@/%/"'"}"
    for pid in $(pgrep -x 'i3'  -u "$(id -u "$USER")"); do
        eval "$(grep -z ^USER /proc/"$pid"/environ | tr '\000' '\n')"
        eval export "$(grep -z ^DISPLAY /proc/"$pid"/environ | tr '\000' '\n')"
        eval export "$(grep -z ^DBUS_SESSION_BUS_ADDRESS /proc/"$pid"/environ | tr '\000' '\n')"

        export IFS=' '
        if [ "$(whoami)" = "$USER" ]; then
            sh -c "$*"
        else
            su "$USER" -c "$*"
        fi
    done
}
