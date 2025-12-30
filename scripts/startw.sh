#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
#
# shellcheck disable=2155
export GTK_THEME=Arc:dark GTK2_RC_FILES=/usr/share/themes/Arc-dark/gtk-2.0/gtkrc QT_STYLE_OVERRIDE=Adwaita-Dark
# set GNOME here so that Electron apps pick up gnome-keyring
export XDG_CURRENT_DESKTOP=SWAY:GNOME XDG_SESSION_TYPE=wayland

eval "$(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets)"
eval "$(ssh-agent -s)"
export SSH_AUTH_SOCK

SWAYDIR="/tmp/$USER/sway"
[ -d "$SWAYDIR" ] || mkdir -p "$SWAYDIR"
touch "$SWAYDIR/startup"

exec sway --unsupported-gpu
# sway
