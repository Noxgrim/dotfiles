// ==UserScript==
// @name         Video Notifier Frontend
// @namespace    http://tampermonkey.net/
// @version      82
// @description  Send a message to another (tridactyl) script if a video about the playback state of videos
// @author       Noxgrim
// @match        *://*/*
// @updateURL    http://localhost:8023/user-scripts/video_notifier.js
// @downloadURL  http://localhost:8023/user-scripts/video_notifier.js
// @run-at       documet-end
// @sandbox      raw
// ==/UserScript==

(function () {
    'use strict';

    // we don't want to double run or run in tridactyl's command line
    // (even if it doesn't hurt)
    if (document.my_noxgrim_loaded_video_checker || window.location.toString().startsWith("moz-extension://")) {
        return;
    }
    document.my_noxgrim_loaded_video_checker = true;
    const name = self.crypto.randomUUID();
    let last = false;
    let lastHref = document.location.href;
    let specialTreatments = new Array()
    const write = function (playing) {
        // to avoid being cancelled or being blocked we use the power of
        // tridactyl to call some local commands (instead of a REST-ish interface
        // which) may be blocked
        // Because CSP we also have to use "*" here (a changing parent should
        // still receive our messages)
        if (playing || last !== playing) {
            const state = playing ? "playing" : "stopped";
            const heartbeat = last === playing ? " (heartbeat)" : "";
            console.debug(`ssuspend.w: ${state} ${name}${heartbeat}`)
            window.parent.postMessage({
                _my_namespace: "noxgrim_video_notifier_worker",
                uuid: name,
                create: playing,
            }, "*");
        }
        last = playing;
    };
    const checkVideos = function (_) {
        let playing = false;
        // i.e. the video is playing (not ended or buffering), in a focussed tab with actual video (and not just
        // audio, as supported by Piped or Invidious)
        if (document.visibilityState !== 'hidden' && !/[&?]listen=(1|true)\b/i.test(window.location.search.substring(1))) {
            for (const v of [...document.querySelectorAll('video')].concat(specialTreatments)) {
                playing = playing || ((v !== null)
                    && !v.paused && v.error === null
                    && !v.ended && v.readyState > 2);
                if (playing) {
                    break;
                }
            }
        }
        write(playing);
    };
    const initEvents = function (v) {
        for (const type of ['play', 'playing', 'pause', 'suspend', 'waiting', 'stalled', 'ended']) {
            v.addEventListener(type, checkVideos);
        }
    };

    // we also want to add our listener to any video which is dynamically loaded
    // and check whether the url was changed… yay
    // https://stackoverflow.com/questions/3522090/event-when-window-location-href-changes/46428962#46428962
    const observer = new MutationObserver((mutations, _) => {
        for (const mut of mutations) {
            let didCheck = false;
            // new nodes were added
            for (const chld of mut.addedNodes) {
                if (chld.nodeName === 'VIDEO') {
                    initEvents(chld);
                } else if (chld.nodeName === 'DISNEY-WEB-PLAYER') {
                    initEvents(chld.mediaElement);
                    specialTreatments.push(chld.mediaElement);
                } else if (chld.querySelectorAll) {
                    chld.querySelectorAll('video').forEach(initEvents);
                    chld.querySelectorAll('disney-web-player').forEach(e => {
                        initEvents(e.mediaElement);
                        specialTreatments.push(e.mediaElement);
                    });
                }
            }
            // a video node was sneakily removed
            for (const chld of mut.removedNodes) {
                if (chld.nodeName === 'DISNEY-WEB-PLAYER') {
                    const idx = specialTreatments.indexOf(chld.mediaElement);
                    if (idx > -1) {
                        specialTreatments.splice(idx, 1);
                        if (!didCheck) {
                            checkVideos(null);
                            didCheck = true;
                        }
                    }
                }
                if (chld.nodeName === 'VIDEO' && !didCheck) {
                    checkVideos(null);
                    didCheck = true;
                } else if (chld.querySelectorAll) {
                    chld.querySelectorAll('disney-web-player').forEach(e => {
                        const idx = specialTreatments.indexOf(e.mediaElement);
                        if (idx > -1) {
                            specialTreatments.splice(idx, 1);
                            if (!didCheck) {
                                checkVideos(null);
                                didCheck = true;
                            }
                        }
                    });
                    if (chld.querySelectorAll('video').length > 0 && !didCheck) {
                        checkVideos(_);
                        didCheck = true;
                    }
                }
            }
            // did the url change without an unload (I guess)?
            if (lastHref !== document.location.href) {
                lastHref = document.location.href;
                if (!didCheck) {
                    checkVideos(_);
                    didCheck = true;
                }
            }
        }
    });

    const checkTabFocus = (_) => {
        if (document.visibilityState === 'hidden') {
            write(false);
        } else {
            checkVideos(_);
        }
    };


    document.querySelectorAll('video').forEach(initEvents);
    document.addEventListener('visibilitychange', checkTabFocus, false);
    // for some reason getting any events (or not cancelling listeners?) when
    // closing a tab is _really_ unreliable (at least in Firefox/LibreWolf)
    // so we just register _all_ the events… the more the merrier
    window.addEventListener('visibilitychange', checkTabFocus, false);
    window.addEventListener('beforeunload', (_) => write(false), false);
    window.addEventListener('unload', (_) => write(false), false);
    window.addEventListener('pagehide', (_) => write(false), false);
    // bubble up any messages to the top whilst checking that it came from on eof our iframes
    if (window.top !== window.self) {
        window.addEventListener('message', (event) => {
            if ([...document.querySelectorAll('iframe')]
                .some(f => f.contentWindow === event.source)) {
                if (event.data._my_namespace === "noxgrim_video_notifier_worker") {
                    window.parent.postMessage(event.data, "*"); // we want to know of redirects
                }
            }

        })
    };
    observer.observe(document, {childList: true, subtree: true});
    // ping everey 60 seconds as a kind of heartbeat
    setInterval(checkVideos, 60 * 1000, null);
    console.debug(`ssuspend.w: loaded video notify worker loaded for frame ${window.location} (${name})`);
})();
