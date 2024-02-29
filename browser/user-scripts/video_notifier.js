// ==UserScript==
// @name         Video Notifier Frontend
// @namespace    http://tampermonkey.net/
// @version      2024-02-29
// @description  Send a message to a local server if a video about the playback state of videos
// @author       Noxgrim
// @match        *://*/*
// @grant        GM.xmlHttpRequest
// @grant        unsafeWindow
// @updateURL    http://localhost:8023/user-scripts/video_notifier.js
// @downloadURL  http://localhost:8023/user-scripts/video_notifier.js
// @connect      localhost
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
    console.log(`ssuspend: loaded video notifier loaded for frame ${window.location} (${name})`);
    const write = function (playing) {
        // be sure that this is sent when the tab is closed (async requests may be cancelled)
        // We could use `navigator.sendBeacon` here but that always uses POST (a no-no with the bad and cursed
        // REST-ish client I implemeted) and needs some extra rules in uBlock Origin (as this API is
        // intended for analytics) so I stick with the blocking call for now (it's local anyways)
        if (last != playing) {
            const state = playing ? "playing" : "stopped";
            console.log(`ssuspend: ${state} ${name}`)
            const request = new XMLHttpRequest();
            request.open(playing ? "PUT" : "DELETE", `http://localhost:8023/video-notification/${name}`, false);
            request.send(null);
        }
        last = playing;
    };
    const checkVideos = function (_) {
        let playing = false;
        // i.e. the video is playing (not ended or buffering), in a focussed tab with actual video (and not just
        // audio, as supported by Piped or Invidious)
        if (document.visibilityState !== 'hidden' && !window.location.search.substring(1).includes('&listen=1')) {
            for (const v of document.querySelectorAll('video')) {
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
                } else if (chld.querySelectorAll) {
                    chld.querySelectorAll('video').forEach(initEvents);
                }
            }
            // a video node was sneakily removed
            for (const chld of mut.removedNodes) {
                if (chld.nodeName === 'VIDEO') {
                    checkVideos(null);
                    didCheck = true;
                    break;
                } else if (chld.querySelectorAll) {
                    if (chld.querySelectorAll('video').length > 0) {
                        checkVideos(_);
                        didCheck = true;
                        break;
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
    unsafeWindow.addEventListener('visibilitychange', checkTabFocus, false);
    unsafeWindow.addEventListener('beforeunload', (_) => write(false), false);
    unsafeWindow.addEventListener('unload', (_) => write(false), false);
    unsafeWindow.addEventListener('pagehide', (_) => write(false), false);
    observer.observe(document, {childList: true, subtree: true});
})();
