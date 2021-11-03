send() {
    if pkill -u "$USER" -f 'xbindkeys$'; then
        # I don't know why I have to sleep here but otherwise it won't work
        # consistently
        xdotool sleep 0.05 key --clearmodifiers "$1"
        xbindkeys
    fi
}

case "$1" in
    close)
        if [ "$(dunstctl count displayed)" -gt 0 ]; then
            dunstctl close
        else
            send 'ctrl+space'
        fi
        ;;
    close-all)
        if [ "$(dunstctl count displayed)" -gt 0 ]; then
            dunstctl close-all
        else
            send 'ctrl+shift+space'
        fi
        ;;
    history-pop)
        if [ "$(dunstctl count history)" -gt 0 ]; then
            dunstctl history-pop
        else
            send 'ctrl+period'
        fi
        ;;
    context)
        if [ "$(dunstctl count displayed)" -gt 0 ]; then
            dunstctl context
        else
            send 'ctrl+shift+period'
        fi
        ;;
    *)
        echo "Expected close, close-all, history-pop, context here"
esac
