// ==UserScript==
// @name         Video Notifier “Backend”
// @namespace    http://tridactyl.xyz/
// @version      82
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
    const ping = "pkill -SIGRTMIN+9 waybar || true";
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
                const file = `"${dir}/browser.${name}"`;
                if (event.data.create) {
                    const content = `printf '%s' '${window.location.toString().replace("'", "'\\''")}'`;
                    const exe = `[ -e ${file} ] || { ${content} > ${file}; ${ping}; }; touch ${file}`;
                    tri.excmds.exclaim_quiet(exe);
                } else {
                    tri.excmds.exclaim_quiet(`rm ${file} || true; ${ping}`);
                }
            }
        } else {
            console.debug("ssuspend.i: received something unfamiliar");
        }
    })
    console.debug(`ssuspend.i: loaded video notify interface loaded for window ${window.location}`);
})()
