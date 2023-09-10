#!/usr/bin/env bash
while ! killall -9 pulseaudio; do sleep 1; done
sleep 2
systemctl --user restart pulseaudio.service
systemctl --user restart mpd.service
