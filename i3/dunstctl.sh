send() {
    if pkill -u "$USER" 'xbindkeys'; then
        # I don't know why I have to sleep here but otherwise it won't work
        # consistently
        xdotool sleep 0.2 key --clearmodifiers "$1"
        xbindkeys
    fi
}

case "$1" in
    close)
        if [ "$(dunstctl count displayed)" -gt 0 ]; then
            dunstctl close
        else
            send 'alt+space'
        fi
        ;;
    close-all)
        if [ "$(dunstctl count displayed)" -gt 0 ]; then
            dunstctl close-all
        else
            send 'alt+shift+space'
        fi
        ;;
    history-pop)
        if [ "$(dunstctl count history)" -gt 0 ]; then
            dunstctl history-pop
        else
            send 'alt+period'
        fi
        ;;
    context)
        if [ "$(dunstctl count displayed)" -gt 0 ]; then
            dunstctl context
        else
            send 'alt+shift+period'
        fi
        ;;
    *)
        echo "Expected close, close-all, history-pop, context here"
esac
