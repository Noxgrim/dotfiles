#! /bin/sh
IMG='/tmp/lock.png'

scrot $IMG
mogrify -blur 4x4 $IMG
i3lock -i $IMG
