#!/bin/bash
THIS="$(readlink -f "$(command -v "$0")")" # path to script
TDIR="$(dirname "$THIS")"
if [ "$XDG_SESSION_TYPE" = 'wayland' ]; then
    source "$TDIR/output_layout.wl.sh"
else
    source "$TDIR/output_layout.x11.sh"
fi
