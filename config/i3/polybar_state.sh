#! /bin/bash
case "$1" in
    show)
        polybar-msg cmd show
        xdo raise -N Polybar
        ;;
    hide)
        polybar-msg cmd hide
        xdo lower -N Polybar
        ;;
    toggle)
        polybar-msg cmd toggle
        xdo raise -N Polybar
        ;;
esac
