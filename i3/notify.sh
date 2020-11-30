# https://bbs.archlinux.org/viewtopic.php?pid=902722#p902722
notify() {
    for pid in $(pgrep -x 'i3'); do
        eval "$(grep -z ^USER /proc/"$pid"/environ | tr '\000' '\n')"
        eval export "$(grep -z ^DISPLAY /proc/"$pid"/environ | tr '\000' '\n')"
        eval export "$(grep -z ^DBUS_SESSION_BUS_ADDRESS /proc/"$pid"/environ | tr '\000' '\n')"

        if [ "$(whoami)" = "$USER" ]; then
            sh -c "notify-send  $*"
        else
            su "$USER" -c "notify-send  $*"
        fi
    done
}
execute() {
    for pid in $(pgrep -x 'i3'); do
        eval "$(grep -z ^USER /proc/"$pid"/environ | tr '\000' '\n')"
        eval export "$(grep -z ^DISPLAY /proc/"$pid"/environ | tr '\000' '\n')"
        eval export "$(grep -z ^DBUS_SESSION_BUS_ADDRESS /proc/"$pid"/environ | tr '\000' '\n')"

        if [ "$(whoami)" = "$USER" ]; then
            sh -c "$*"
        else
            su "$USER" -c "$*"
        fi
    done
}
