#!/bin/bash
source "$HOME/.device_specific/default_source.sh"
for SOURCE in "${SOURCES[@]}"; do
    pactl set-source-volume "$SOURCE" 100%
done
