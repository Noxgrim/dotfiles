#! /bin/bash
set -eu -o pipefail
# This is a script meant to interact with an instace of Firefox which runs the
# web version of Discord and do some things Discord is not able to do on its
# own. The browser has 'tridactly' (which is used to define the keybinds
# pressed; they are bind to the JS shown in the comments), 'Window Titler' (set
# “Messenger”) and 'Tab ReTitle' (to ensure that the Discord tab always has the
# same name)

FOCUS="false"
case "$1" in
    invisible|offline)
        # if(document.getElementById("status-picker-idle") == null)
        #   document.querySelector("[aria-label=\"Set Status\"]").click();
        # document.getElementById("status-picker-idle").click();
        # tri.excmds.focusinput("-l");
        KEYS="gsi"
        ;;
    dnd|do-not-disturb)
        # if(document.getElementById("status-picker-idle") == null)
        #   document.querySelector("[aria-label=\"Set Status\"]").click();
        # document.getElementById("status-picker-dnd").click();
        # tri.excmds.focusinput("-l");
        KEYS="gsn"
        ;;
    idle|away)
        # if(document.getElementById("status-picker-idle") == null)
        #   document.querySelector("[aria-label=\"Set Status\"]").click();
        # document.getElementById("status-picker-idle").click();
        # tri.excmds.focusinput("-l");
        KEYS="gsa"
        ;;
    online)
        # if(document.getElementById("status-picker-idle") == null)
        #   document.querySelector("[aria-label=\"Set Status\"]").click();
        # document.getElementById("status-picker-online").click();
        # tri.excmds.focusinput("-l");
        KEYS="gso"
        ;;
    mute)
        # qs = document.querySelector("[aria-label=\"Mute\"]");
        # if (qs != null)
        #   qs.click();
        # tri.excmds.focusinput("-l");
        KEYS="gsm"
        ;;
    deafen)
        # qs = document.querySelector("[aria-label=\"Deafen\"]");
        # if (qs != null)
        #   qs.click();
        # tri.excmds.focusinput("-l");
        KEYS="gsd"
        ;;
    leave|disconnect)
        # qs = document.querySelector("[aria-label=\"Disconnect\"]");
        # if (qs != null)
        #   qs.click();
        # tri.excmds.focusinput("-l");
        KEYS="gsl"
        ;;
    accept|join|join-voice|accept-voice)
        # qs = document.querySelector("[aria-label=\"Join Call\"]");
        # if (qs != null)
        #   qs.click();
        # tri.excmds.focusinput("-l");
        KEYS="gsj"
        ;;
    accept-video|join-video)
        # qs = document.querySelector("[aria-label=\"Join Video Call\"]");
        # if (qs != null)
        #   qs.click();
        # tri.excmds.focusinput("-l");
        KEYS="gsJ"
        ;;
    reject|dismiss)
        # qs = document.querySelector("[aria-label=\"Dismiss\"]");
        # if (qs != null)
        #   qs.click();
        # tri.excmds.focusinput("-l");
        KEYS="gsr"
        ;;
    call|voice-call)
        # qs  = document.querySelector("[aria-label=\"Start Voice Call\"]");
        # if (qs != null) {
        #   qs.click();
        #   tri.excmds.focusinput("-l");
        # }
        KEYS="gsc"
        ;;
    video|video-call|camera)
        # qs  = document.querySelector("[aria-label=\"Start Video Call\"],[aria-label=\"Turn on Camera\"],[aria-label=\"Turn off Camera\"]");
        # if (qs != null) {
        #   qs.click();
        #   tri.excmds.focusinput("-l");
        # }
        KEYS="gsv"
        ;;
    video-stop|video-call-stop|camera-stop)
        # qs  = document.querySelector("[aria-label=\"Turn off Camera\"]");
        # if (qs != null) {
        #   qs.click();
        #   tri.excmds.focusinput("-l");
        # }
        KEYS="gsV"
        ;;
    share|share-screen)
        # qs = document.querySelector("[aria-label=\"Stop Streaming\"]");
        # if (qs != null) {
        #   qs.click();
        #   tri.excmds.focusinput("-l");
        # } else {
        #   qs = document.querySelector("[aria-label=\"Share Your Screen\"]");
        #   if (qs != null)
        #     qs.click();
        # }
        KEYS="gss"
        FOCUS="true"
        ;;
    stop-share|share-screen-stop)
        # qs = document.querySelector("[aria-label=\"Stop Streaming\"]");
        # if (qs != null) {
        #   qs.click();
        #   tri.excmds.focusinput("-l");
        # }
        KEYS="gsS"
        ;;
    go|go-away)
        # not at all far too complicated or anything
        # only do something if there is no state and save state of status, mute and video

        # if (typeof noxgrim_status === "undefined" && typeof noxgrim_was_muted === "undefined" && typeof noxgrim_was_video === "undefined") {
        #     switch (document.querySelector("[aria-label=\"Set Status\"]>[aria-label]").getAttribute("aria-label").split(", ").pop()) {
        #         case "Online":
        #             noxgrim_status = "online";
        #             break;
        #         case "Idle":
        #             noxgrim_status = "idle";
        #             break;
        #         case "Do Not Disturb":
        #             noxgrim_status = "dnd";
        #             break;
        #         case "Invisible":
        #             noxgrim_status = "invisible";
        #             break;
        #     }
        #     if (noxgrim_status !== "invisible") {
        #         if (document.getElementById("status-picker-idle") == null)
        #             document.querySelector("[aria-label=\"Set Status\"]").click();
        #         document.getElementById("status-picker-idle").click();
        #     }
        #     noxgrim_was_muted = document.querySelector("[aria-label=\"Mute\"] path[class^=\"strikethrough\"]") != null;
        #     if (!noxgrim_was_muted)
        #         document.querySelector("[aria-label=\"Mute\"]").click();
        #     noxgrim_was_video = document.querySelector("[aria-label=\"Turn off Camera\"]");
        #     if (noxgrim_was_video != null)
        #         noxgrim_was_video.click();
        #     noxgrim_was_video = noxgrim_was_video != null;
        # }
        # tri.excmds.focusinput("-l");
        KEYS="gsg"
        ;;
    come|come-back)
        # not at all far too complicated or anything
        # restore previously saved status, mute and video

        # if (typeof noxgrim_status !== "undefined" && typeof noxgrim_was_video !== "undefined" && typeof noxgrim_was_muted !== "undefined") {
        #     if (noxgrim_status !== "invisible") {
        #         if (document.getElementById("status-picker-idle") == null)
        #             document.querySelector("[aria-label=\"Set Status\"]").click();
        #         document.getElementById("status-picker-" + noxgrim_status).click();
        #     }
        #     noxgrim_muted = document.querySelector("[aria-label=\"Mute\"] path[class^=\"strikethrough\"]") != null;
        #     if (noxgrim_muted && !noxgrim_was_muted)
        #         document.querySelector("[aria-label=\"Mute\"]").click();
        #     noxgrim_video = document.querySelector("[aria-label=\"Turn on Camera\"]");
        #     if (noxgrim_video != null && noxgrim_was_video)
        #         noxgrim_video.click();
        # }
        # noxgrim_was_muted = noxgrim_muted = noxgrim_was_video = noxgrim_video = noxgrim_status = undefined;
        # tri.excmds.focusinput("-l");
        KEYS="gsb"
        ;;
    none)
        exit 0
        ;;
    usage);&
    *)
        echo 'Unknown command: '"${1:-}" >&2
        echo 'Use: invisible|offline,dnd|do-not-disturb,idle|away,online' >&2
        echo '     mute,deafen' >&2
        echo '     accept|accept-voice|join|join-voice,reject|dismiss,leave|disconnect' >&2
        echo '     accept-video|join-video' >&2
        echo '     video|video-call|camera' >&2
        echo '     video-stop|video-call-stop|camera-stop' >&2
        echo '     share|share-screen' >&2
        echo '     stop-share|share-screen-stop' >&2
        echo '     go|go-away,back|come-back' >&2
        exit 1
        ;;
esac

DISCORD_WINDOWS="$(xdotool search --class "noxgrim_messengers" | # the class can be set with FF's ‘--class’ option
                   xargs  -I{} sh -c 'if xprop -id {} | grep -q ^WM_WINDOW_ROLE".*browser"; then echo {}; fi')"
[ -z "$DISCORD_WINDOWS" ] && echo "Discord not found!" >&2 && exit 1
for ID in $DISCORD_WINDOWS; do
    if ! xprop -id "$ID" | grep '^WM_NAME' | grep -q '\[Messenger] Discord'; then
        xdotool key  --window "$ID" --delay 50 Ctrl+l Tab Tab Tab Escape
        sleep 0.050s
        xdotool type --window "$ID" --delay 50 --args 1 bDiscord
        sleep 0.050s
        xdotool key  --window "$ID" Enter

        WIN_ACTIVE="$(xdotool getactivewindow)"
        set +o pipefail
        WAS_IN_SCRATCHPAD=$(xprop -id "$ID" | grep -qm 1 '^\s*window state: Withdrawn' && echo true || echo false)
        set -o pipefail
        WAS_FULL_SCREEN="$(i3-msg -t get_tree | jq '..|select(.window? and .window_type? and .window_type and .window=='"$WIN_ACTIVE"')|.fullscreen_mode==1')"
        xdotool windowactivate "$ID"
        sleep 0.05s
        "$WAS_IN_SCRATCHPAD" && i3-msg "[id=$ID]" scratchpad show > /dev/null || true
        xdotool windowactivate "$WIN_ACTIVE"
        if "$WAS_FULL_SCREEN" [ "$WIN_ACTIVE" != "$ID" ]; then
            i3-msg "[id=$WIN_ACTIVE]" fullscreen > /dev/null || true
        fi
        if ! xprop -id "$ID" | grep '^WM_NAME' | grep -q '\[Messenger] Discord'; then
            xdotool key  --window "$ID" Escape
            echo "Discord not found!" >&2 && exit 1
        else
            echo "$ID $KEYS (active:$WIN_ACTIVE discord-scratchpad:$WAS_IN_SCRATCHPAD active-fullscreen:$WAS_FULL_SCREEN)"
        fi
    else
        echo "$ID $KEYS"
    fi
    xdotool key  --window "$ID" --delay 50 Ctrl+l Tab Tab Tab Escape
    sleep 0.05s
    xdotool type --window "$ID" --delay 50 --args 1 "$KEYS"
    "$FOCUS" && xdotool windowactivate "$ID" || true
done
[ -z "$DISCORD_WINDOWS" ] && echo "Discord not found!" >&2 && exit 1
