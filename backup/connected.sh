#!/usr/bin/env bash
THISDIR="$(dirname "$(readlink -f "$0")")"
source "$THISDIR/backup.conf"

if [ -e "/dev/disk/by-uuid/$DEVICEUUID" ] && systemctl is-enabled -q backup.timer; then # check for existence
	echo 'Should back up.'
	exit 0
else
	echo 'Will not back back up.'
	exit 1
fi
