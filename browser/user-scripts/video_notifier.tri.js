// ==UserScript==
// @name         Video Notifier “Backend”
// @namespace    http://tridactyl.xyz/
// @version      81
// @description  Receive messages about video notifications from the local website and make changes to local file system
// @author       Noxgrim
// @match        *://*/*
// @updateURL    http://localhost:8023/user-scripts/video_notifier.tri.js
// @downloadURL  http://localhost:8023/user-scripts/video_notifier.tri.js
// @run-at       documet-start
// @sandbox      raw
// ==/UserScript==

(function () {
    'use strict';

    const dir = "/tmp/$USER/ssuspend"
    tri.excmds.exclaim_quiet(`[ -d "${dir}" ] || mkdir -p "${dir}"`);

    window.addEventListener('message', (event) => {
        if (window === event.source || [...document.querySelectorAll('iframe')]
            .some(f => f.contentWindow === event.source)) {
            if (event.data._my_namespace === "noxgrim_video_notifier_worker") {
                const name = event.data.uuid;
                if (!/^[a-zA-Z0-9_-]+$/.test(name)) {
                    console.error(`ssuspend.i: uuid doesn't match expectations! ${name}`);
                    return;
                }
                if (event.data.create) {
                    tri.excmds.exclaim_quiet(`printf '%s' '${window.location.toString().replace("'", "'\\''")}' > "${dir}/browser.${name}"; pkill -SIGRTMIN+9 waybar || true`);
                } else {
                    tri.excmds.exclaim_quiet(`rm "${dir}/browser.${name}" || true; pkill -SIGRTMIN+9 waybar || true`);
                }
            }
        } else {
            console.debug("ssuspend.i: received something unfamiliar");
        }
    })
    console.debug(`ssuspend.i: loaded video notify interface loaded for window ${window.location}`);
})()
