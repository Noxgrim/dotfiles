#!/usr/bin/env bash
THISDIR="$(dirname "$(readlink -f "$0")")"
source "$THISDIR/backup.conf"

if [ -e "/dev/disk/by-uuid/$DEVICEUUID" ] && systemctl is-enabled -q backup.timer && \
	[ ! -e '/tmp/backup_suspend' ]; then
	if systemctl is-active -q backup.service || [ "$( pgrep -cf "borg" )" -le 1 ] ; then # check for existence
		echo 'Should back up.'
		exit 0
	fi
fi

echo 'Will not back back up.'
exit 1
