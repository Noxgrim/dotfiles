(function () {
    if (document.my_noxgrim_loaded_video_checker) {
        return;
    }
    document.my_noxgrim_loaded_video_checker = true;
    const name = self.crypto.randomUUID();
    const dir = "/tmp/$USER/ssuspend"
    let last = false;
    console.log("ssuspend: loaded video notifier");
    const write = function (playing) {
        if (last != playing) {
            console.log(`ssuspend: ${playing ? "playing" : "stopped"} ${name}`)
            if (playing) {
                tri.excmds.exclaim_quiet(`[ -d "${dir}" ] || mkdir -p "${dir}"; touch "${dir}/browser.${name}"`)
            } else {
                tri.excmds.exclaim_quiet(`[ -d "${dir}" ] || mkdir -p "${dir}"; rm "${dir}/browser.${name}" || true`)
            }
        }
    };
    const check = function (_) {
        let playing = false;
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
        last = playing;
    };
    const initEvents = function (v) {
        for (e of ['play', 'playing', 'pause', 'suspend', 'waiting', 'stalled', 'ended']) {
            v.addEventListener(e, check);
        }
    };

    const observer = new MutationObserver((mutations, _) => {
        for (const mut of mutations) {
            for (const chld of mut.addedNodes) {
                if (chld.nodeName === 'VIDEO') {
                    initEvents(chld);
                } else if (chld.querySelectorAll) {
                    chld.querySelectorAll('video').forEach(initEvents);
                }
            }
        }
    })


    document.querySelectorAll('video').forEach(initEvents);
    document.addEventListener('visibilitychange', check);
    addEventListener('beforeunload', (_) => write(false));
    observer.observe(document, {childList: true, subtree: true});
})()
