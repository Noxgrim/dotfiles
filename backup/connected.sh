#!/usr/bin/env bash
#shellcheck disable=2155
readonly THISDIR="$(dirname "$(readlink -f "$0")")"
#shellcheck disable=1091
source "$THISDIR/backup.conf"

check_can_run() {
	if [ -e "/dev/disk/by-uuid/$DEVICEUUID" ] && systemctl is-enabled -q backup.timer; then
		if $ALLOW_SUSPEND && [ -e '/tmp/backup_suspend' ]; then
			return
		fi
		if $ALLOW_DISABLE && [ -O '/tmp/backup_disable' ]; then
			return
		fi
		if systemctl is-active -q backup.service || [ "$( pgrep -cf '(^|/)[b]org ' )" = 0 ] ; then # check for existence
			echo 'Should back up.'
			exit 0
		fi
	fi
}

check_can_run


echo 'Will not back back up.'
exit 1
