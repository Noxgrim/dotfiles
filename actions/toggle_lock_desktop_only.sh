#!/bin/bash
if [ -e "/tmp/$USER/lock_show_desktop_only" ]; then
    rm -f "/tmp/$USER/lock_show_desktop_only"
else
    [ -d "/tmp/$USER" ] || mkdir "/tmp/$USER"
    touch "/tmp/$USER/lock_show_desktop_only"
fi
